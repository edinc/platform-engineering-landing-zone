#!/usr/bin/env bash
#
# brownfield-discovery.sh — READ-ONLY discovery of an existing Azure tenant or
# subscription before applying the Stage 02 ALZ baseline. It performs NO writes:
# every `az` call is a `list`/`show`. Use it to validate the brownfield onramp
# (acceptance criterion 7) and to size the policy-exemption inventory before any
# effect is moved to Deny.
#
# What it reports:
#   1. Signed-in context (tenant, subscription).
#   2. Existing management-group hierarchy.
#   3. Existing policy assignments at the target scope (so the baseline does not
#      silently collide with assignments already in place).
#   4. Existing Defender for Cloud pricing tiers on the subscription.
#   5. Resources missing any of the eight mandatory tags (the tag-baseline Deny
#      blast radius — fix or exempt these before enabling Deny).
#
# Usage:
#   scripts/alz/brownfield-discovery.sh [-s <subscription-id>] [-g <mg-id>] [-o <out-dir>]
#
#   -s  Subscription to inspect for Defender + untagged resources.
#       Defaults to the current `az account show` subscription.
#   -g  Management group ID to root the hierarchy/assignment listing at.
#       Defaults to the tenant root MG (the tenant ID).
#   -o  Directory to also write JSON snapshots into (optional; default: none,
#       human-readable output to stdout only).
#
# Requires: az CLI (logged in via `az login`), jq. No Owner/Contributor needed —
# Reader at the inspected scope is sufficient.
set -euo pipefail

log()  { printf '\033[0;34m[discover]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[   ok   ]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[  warn  ]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[  fail  ]\033[0m %s\n' "$*" >&2; exit 1; }

SUBSCRIPTION_ID=""
MG_ID=""
OUT_DIR=""

while getopts ":s:g:o:h" opt; do
  case "$opt" in
    s) SUBSCRIPTION_ID="$OPTARG" ;;
    g) MG_ID="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    h) sed -nE 's/^# ?//p' "$0" | sed -n '2,40p'; exit 0 ;;
    *) die "Unknown option. Run with -h for usage." ;;
  esac
done

command -v az >/dev/null 2>&1 || die "az CLI is required (az login first)."
command -v jq >/dev/null 2>&1 || die "jq is required."

# Safety guard: the JSON snapshots contain tenant-specific inventory (subscription
# IDs are embedded in every resource ARM ID). Refuse to write them into a git
# worktree path that is NOT gitignored, so a routine `git add` cannot commit a
# tenant's inventory. A gitignored path (e.g. ./.discovery) or an out-of-repo
# path is allowed.
guard_out_dir() {
  [[ -n "$OUT_DIR" ]] || return 0
  command -v git >/dev/null 2>&1 || return 0
  local toplevel abs
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  abs="$(cd "$(dirname "$OUT_DIR")" 2>/dev/null && printf '%s/%s' "$(pwd)" "$(basename "$OUT_DIR")")" || abs="$OUT_DIR"
  case "$abs" in
    "$toplevel"/*|"$toplevel")
      # Check a representative snapshot path inside OUT_DIR (emit writes *.json
      # there); a trailing-slash gitignore pattern matches the dir's contents,
      # not the bare dir path.
      if ! git -C "$toplevel" check-ignore -q "${abs}/snapshot.json"; then
        die "Refusing to write tenant inventory to '${OUT_DIR}': it is inside the git repo but not gitignored. Use a gitignored path (e.g. ./.discovery) or a path outside the repo."
      fi
      ;;
  esac
}
guard_out_dir

# The eight mandatory tags from plan/plan.md section 10 (kept in lockstep with
# policies/azure/initiatives/tag-baseline.json and the Rego tag policy).
MANDATORY_TAGS=(env owner costCenter product dataClassification confidentiality managedBy repo)

ACCOUNT_JSON="$(az account show -o json 2>/dev/null)" || die "Not logged in. Run 'az login'."
TENANT_ID="$(jq -r '.tenantId' <<<"$ACCOUNT_JSON")"
[[ -n "$SUBSCRIPTION_ID" ]] || SUBSCRIPTION_ID="$(jq -r '.id' <<<"$ACCOUNT_JSON")"
[[ -n "$MG_ID" ]] || MG_ID="$TENANT_ID"

emit() { # emit <name> <json>
  [[ -n "$OUT_DIR" ]] || return 0
  mkdir -p "$OUT_DIR"
  printf '%s' "$2" >"${OUT_DIR}/$1.json"
}

log "Tenant:        ${TENANT_ID}"
log "Subscription:  ${SUBSCRIPTION_ID}"
log "MG scope:      ${MG_ID}"
[[ -n "$OUT_DIR" ]] && log "JSON snapshots: ${OUT_DIR}"
echo

# 1. Management-group hierarchy ------------------------------------------------
log "Management-group hierarchy under '${MG_ID}':"
if MG_JSON="$(az account management-group show --name "$MG_ID" --expand --recurse -o json 2>/dev/null)"; then
  emit "management-groups" "$MG_JSON"
  jq -r '
    def walk($d): "  " * $d + "- " + (.displayName // .name) + " (" + .name + ")",
      (.children // [] | .[] | walk($d + 1));
    walk(0)' <<<"$MG_JSON" 2>/dev/null || jq -r '.name' <<<"$MG_JSON"
  ok "Hierarchy listed (no changes made)."
else
  warn "Could not read management group '${MG_ID}'. You may lack Reader at the MG scope, or MGs are not in use yet."
fi
echo

# 2. Existing policy assignments at the MG scope -------------------------------
log "Existing policy assignments at scope '${MG_ID}':"
MG_SCOPE="/providers/Microsoft.Management/managementGroups/${MG_ID}"
if PA_JSON="$(az policy assignment list --scope "$MG_SCOPE" -o json 2>/dev/null)"; then
  emit "policy-assignments" "$PA_JSON"
  COUNT="$(jq 'length' <<<"$PA_JSON")"
  jq -r '.[] | "  - " + .name + "  (enforcementMode=" + (.enforcementMode // "Default") + ")"' <<<"$PA_JSON"
  ok "${COUNT} existing assignment(s) found. Reconcile names before applying the baseline."
else
  warn "Could not list policy assignments at '${MG_SCOPE}'."
fi
echo

# 3. Defender for Cloud pricing on the subscription ----------------------------
log "Defender for Cloud pricing tiers on subscription '${SUBSCRIPTION_ID}':"
if PRICE_JSON="$(az security pricing list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
  emit "defender-pricing" "$PRICE_JSON"
  jq -r '.value[]? // .[]? | "  - " + .name + ": " + (.pricingTier // "unknown")' <<<"$PRICE_JSON" 2>/dev/null \
    || warn "Defender pricing returned an unexpected shape; see the JSON snapshot."
  ok "Pricing listed. Standard plans are charged; demo defaults to Free (ADR-0011)."
else
  warn "Could not read Defender pricing (needs the Microsoft.Security RP and Reader)."
fi
echo

# 4. Resources missing mandatory tags (tag-baseline Deny blast radius) ---------
log "Scanning subscription '${SUBSCRIPTION_ID}' for resources missing mandatory tags:"
log "Mandatory tags: ${MANDATORY_TAGS[*]}"
TAG_KEYS_JSON="$(printf '%s\n' "${MANDATORY_TAGS[@]}" | jq -R . | jq -s .)"
if RES_JSON="$(az resource list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
  # List resources missing at least one mandatory tag.
  REPORT="$(jq --argjson keys "$TAG_KEYS_JSON" -r '
    map( . as $r
         | { id: $r.id, type: $r.type,
             missing: [ $keys[] | select( ($r.tags // {})[.] == null ) ] } )
    | map(select(.missing | length > 0)) as $bad
    | ($bad | length) as $n
    | "  Non-compliant resources: \($n)",
      ( $bad[:50][] | "  - [" + (.missing | join(",")) + "] " + .type + "  " + .id )
  ' <<<"$RES_JSON")"
  emit "untagged-resources" "$RES_JSON"
  printf '%s\n' "$REPORT"
  BADN="$(jq --argjson keys "$TAG_KEYS_JSON" 'map(select(.tags as $t | [ $keys[] | select( ($t // {})[.] == null ) ] | length > 0)) | length' <<<"$RES_JSON")"
  if [[ "$BADN" -gt 0 ]]; then
    warn "${BADN} resource(s) miss at least one mandatory tag. Tag or exempt them BEFORE enabling tag-baseline Deny (ADR-0027)."
  else
    ok "All resources carry the mandatory tags."
  fi
else
  warn "Could not list resources (needs Reader on the subscription)."
fi
echo

ok "Discovery complete. This script made NO changes to your tenant."
