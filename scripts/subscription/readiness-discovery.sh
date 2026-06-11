#!/usr/bin/env bash
#
# readiness-discovery.sh — READ-ONLY discovery of an existing Azure subscription
# before applying the Stage 02 subscription baseline. It performs NO writes: every
# `az` call is a `list`/`show`. Use it to validate the brownfield onramp and to
# size the policy-exemption/tag remediation inventory before onboarding.
#
# What it reports:
#   1. Signed-in context (tenant, subscription).
#   2. Existing/inherited policy assignments visible at the subscription scope.
#   3. Existing Defender for Cloud pricing tiers on the subscription.
#   4. Required resource provider registration state.
#   5. Subscription Activity Log diagnostic settings.
#   6. Resource groups and resources missing any of the eight mandatory tags.
#
# Usage:
#   scripts/subscription/readiness-discovery.sh [-s <subscription-id>] [-p <required-policy-match>]... [-x] [-o <out-dir>]
#
#   -s  Subscription to inspect. Defaults to the current `az account show`
#       subscription.
#   -o  Directory to also write JSON snapshots into (optional; default: none,
#       human-readable output to stdout only).
#   -p  Required inherited policy assignment match. Repeat for each expected
#       assignment or policy definition ID/name (for example CIS v2, tag
#       baseline). The script fails if any required match is absent.
#   -x  Skip required policy verification. Use only when an approved ALZ
#       exception/change ticket covers the missing inherited assignments.
#
# Requires: az CLI (logged in via `az login`), jq. No Owner/Contributor needed;
# Reader at the inspected subscription is sufficient for the inventory sections.
set -euo pipefail

log()  { printf '\033[0;34m[discover]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[   ok   ]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[  warn  ]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[  fail  ]\033[0m %s\n' "$*" >&2; exit 1; }

SUBSCRIPTION_ID=""
OUT_DIR=""
REQUIRED_POLICY_MATCHES=()
SKIP_POLICY_REQUIREMENTS="false"

while getopts ":s:o:p:xh" opt; do
  case "$opt" in
    s) SUBSCRIPTION_ID="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    p) REQUIRED_POLICY_MATCHES+=("$OPTARG") ;;
    x) SKIP_POLICY_REQUIREMENTS="true" ;;
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
  case "$OUT_DIR" in
    /*) abs="$OUT_DIR" ;;
    *) abs="$(pwd -P)/$OUT_DIR" ;;
  esac
  case "$abs" in
    "$toplevel"/*|"$toplevel")
      # Check a representative snapshot path inside OUT_DIR (emit writes *.json
      # there); a trailing-slash gitignore pattern matches the dir's contents,
      # not the bare dir path.
      if ! git -C "$toplevel" check-ignore -q "${abs}/snapshot.json"; then
        die "Refusing to write subscription inventory to '${OUT_DIR}': it is inside the git repo but not gitignored. Use a gitignored path (e.g. ./.discovery) or a path outside the repo."
      fi
      ;;
  esac
}
guard_out_dir

# The eight mandatory tags from plan/plan.md section 10 (kept in lockstep with
# policies/azure/initiatives/tag-baseline.json and the Rego tag policy).
MANDATORY_TAGS=(env owner costCenter product dataClassification confidentiality managedBy repo)
REQUIRED_RESOURCE_PROVIDERS=(Microsoft.Security)
OPTIONAL_RESOURCE_PROVIDERS=(Microsoft.Insights Microsoft.CostManagement Microsoft.Consumption)

ACCOUNT_JSON="$(az account show -o json 2>/dev/null)" || die "Not logged in. Run 'az login'."
TENANT_ID="$(jq -r '.tenantId' <<<"$ACCOUNT_JSON")"
[[ -n "$SUBSCRIPTION_ID" ]] || SUBSCRIPTION_ID="$(jq -r '.id' <<<"$ACCOUNT_JSON")"
SUBSCRIPTION_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

emit() { # emit <name> <json>
  [[ -n "$OUT_DIR" ]] || return 0
  mkdir -p "$OUT_DIR"
  printf '%s' "$2" >"${OUT_DIR}/$1.json"
}

log "Tenant:        ${TENANT_ID}"
log "Subscription:  ${SUBSCRIPTION_ID}"
[[ -n "$OUT_DIR" ]] && log "JSON snapshots: ${OUT_DIR}"
echo

# 1. Policy assignments visible/inherited at subscription scope ------------------
log "Policy assignments visible at subscription scope '${SUBSCRIPTION_SCOPE}' (including inherited parent scopes):"
if PA_JSON="$(az policy assignment list --scope "$SUBSCRIPTION_SCOPE" --disable-scope-strict-match -o json 2>/dev/null)"; then
  emit "policy-assignments" "$PA_JSON"
  COUNT="$(jq 'length' <<<"$PA_JSON")"
  jq -r '.[] | "  - " + .name + "  (enforcementMode=" + (.enforcementMode // "Default") + ", scope=" + (.scope // "unknown") + ")"' <<<"$PA_JSON"
  ok "${COUNT} assignment(s) listed."

  if [[ "${#REQUIRED_POLICY_MATCHES[@]}" -eq 0 ]]; then
    if [[ "$SKIP_POLICY_REQUIREMENTS" == "true" ]]; then
      warn "Required inherited policy verification skipped. Ensure the approved ALZ exception/change ticket is recorded in the onboarding PR."
    else
      die "No required policy expectations supplied. Re-run with one or more -p values for expected inherited ALZ/CIS/tag assignments, or -x only with an approved exception."
    fi
  else
    missing=()
    for required in "${REQUIRED_POLICY_MATCHES[@]}"; do
      if ! jq -e --arg required "$required" --arg subscription_scope "$SUBSCRIPTION_SCOPE" '
        ($required | ascii_downcase) as $needle
        | any(.[]; (.scope // "" | ascii_downcase) as $scope
            | ($scope != ($subscription_scope | ascii_downcase)
              and ($scope | startswith(($subscription_scope | ascii_downcase) + "/") | not)
              and ([
                (.name // ""),
                (.displayName // ""),
                (.id // "" | split("/") | last),
                (.policyDefinitionId // "")
              ] | map(ascii_downcase) | any(contains($needle)))))
      ' <<<"$PA_JSON" >/dev/null; then
        missing+=("$required")
      fi
    done

    if [[ "${#missing[@]}" -gt 0 ]]; then
      printf -v missing_joined '%s, ' "${missing[@]}"
      die "Missing required inherited policy assignment match(es): ${missing_joined%, }. Confirm ALZ placement/policy inheritance or document an approved exception."
    fi
    ok "Required inherited policy assignment expectations are present."
  fi
else
  if [[ "$SKIP_POLICY_REQUIREMENTS" == "true" ]]; then
    warn "Could not list policy assignments at '${SUBSCRIPTION_SCOPE}', but verification was explicitly skipped."
  else
    die "Could not list policy assignments at '${SUBSCRIPTION_SCOPE}'. Fix access or use -x only with an approved exception."
  fi
fi
echo

# 2. Defender for Cloud pricing on the subscription -----------------------------
log "Defender for Cloud pricing tiers on subscription '${SUBSCRIPTION_ID}':"
if PRICE_JSON="$(az security pricing list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
  emit "defender-pricing" "$PRICE_JSON"
  jq -r '.value[]? // .[]? | "  - " + .name + ": " + (.pricingTier // "unknown")' <<<"$PRICE_JSON" 2>/dev/null \
    || warn "Defender pricing returned an unexpected shape; see the JSON snapshot."
  ok "Pricing listed. Stage 02 may update these tiers through the subscription-baseline stack."
else
  warn "Could not read Defender pricing (needs the Microsoft.Security RP and Reader)."
fi
echo

# 3. Resource provider registration ---------------------------------------------
log "Resource provider registration state:"
RP_SUMMARY="[]"
MISSING_RESOURCE_PROVIDERS=()
for rp in "${REQUIRED_RESOURCE_PROVIDERS[@]}" "${OPTIONAL_RESOURCE_PROVIDERS[@]}"; do
  if RP_STATE="$(az provider show --namespace "$rp" --subscription "$SUBSCRIPTION_ID" --query registrationState -o tsv 2>/dev/null)"; then
    printf '  - %s: %s\n' "$rp" "$RP_STATE"
    RP_SUMMARY="$(jq --arg namespace "$rp" --arg state "$RP_STATE" '. + [{namespace: $namespace, registrationState: $state}]' <<<"$RP_SUMMARY")"
    if [[ "$RP_STATE" != "Registered" ]]; then
      if [[ " ${REQUIRED_RESOURCE_PROVIDERS[*]} " == *" ${rp} "* ]]; then
        warn "${rp} is ${RP_STATE}; register it before applying the subscription baseline."
        MISSING_RESOURCE_PROVIDERS+=("${rp}=${RP_STATE}")
      else
        warn "${rp} is ${RP_STATE}; register it before enabling the optional baseline feature that uses it."
      fi
    fi
  else
    warn "Could not read registration state for ${rp}."
    RP_SUMMARY="$(jq --arg namespace "$rp" '. + [{namespace: $namespace, registrationState: "unknown"}]' <<<"$RP_SUMMARY")"
    if [[ " ${REQUIRED_RESOURCE_PROVIDERS[*]} " == *" ${rp} "* ]]; then
      MISSING_RESOURCE_PROVIDERS+=("${rp}=unknown")
    fi
  fi
done
emit "resource-providers" "$RP_SUMMARY"
if [[ "${#MISSING_RESOURCE_PROVIDERS[@]}" -gt 0 ]]; then
  printf -v missing_rps '%s, ' "${MISSING_RESOURCE_PROVIDERS[@]}"
  die "Required resource provider(s) are not ready: ${missing_rps%, }. Register them before applying the subscription baseline."
fi
ok "Required resource providers are registered. Optional providers are listed above for feature planning."
echo

# 4. Activity Log diagnostic settings ------------------------------------------
log "Subscription Activity Log diagnostic settings:"
if DIAG_JSON="$(az monitor diagnostic-settings subscription list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
  emit "activity-log-diagnostics" "$DIAG_JSON"
  DIAG_LIST="$(jq 'if type == "object" and has("value") then .value else . end' <<<"$DIAG_JSON")"
  COUNT="$(jq 'length' <<<"$DIAG_LIST")"
  jq -r '.[] | "  - " + .name + " -> " + (.workspaceId // .storageAccountId // .eventHubAuthorizationRuleId // "unknown destination")' <<<"$DIAG_LIST"
  ok "${COUNT} diagnostic setting(s) listed. Stage 02 can create one when log_analytics_workspace_id is supplied."
else
  warn "Could not list subscription diagnostic settings (needs Microsoft.Insights access)."
fi
echo

# 5. Resource groups and resources missing mandatory tags ------------------------
log "Scanning subscription '${SUBSCRIPTION_ID}' for resource groups and resources missing mandatory tags:"
log "Mandatory tags: ${MANDATORY_TAGS[*]}"
TAG_KEYS_JSON="$(printf '%s\n' "${MANDATORY_TAGS[@]}" | jq -R . | jq -s .)"

if RG_JSON="$(az group list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
  RG_REPORT="$(jq --argjson keys "$TAG_KEYS_JSON" -r '
    map( . as $r
         | { id: $r.id, type: "Microsoft.Resources/resourceGroups",
             missing: [ $keys[] | select( ($r.tags // {})[.] == null ) ] } )
    | map(select(.missing | length > 0)) as $bad
    | ($bad | length) as $n
    | "  Non-compliant resource groups: \($n)",
      ( $bad[:50][] | "  - [" + (.missing | join(",")) + "] " + .type + "  " + .id )
  ' <<<"$RG_JSON")"
  emit "untagged-resource-groups" "$RG_JSON"
  printf '%s\n' "$RG_REPORT"
  BAD_RGN="$(jq --argjson keys "$TAG_KEYS_JSON" 'map(select(.tags as $t | [ $keys[] | select( ($t // {})[.] == null ) ] | length > 0)) | length' <<<"$RG_JSON")"
  if [[ "$BAD_RGN" -gt 0 ]]; then
    warn "${BAD_RGN} resource group(s) miss at least one mandatory tag. Tag or exempt them through the ALZ policy exception process before tightening enforcement."
  else
    ok "All resource groups carry the mandatory tags."
  fi
else
  warn "Could not list resource groups (needs Reader on the subscription)."
fi

if RES_JSON="$(az resource list --subscription "$SUBSCRIPTION_ID" -o json 2>/dev/null)"; then
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
    warn "${BADN} resource(s) miss at least one mandatory tag. Tag or exempt them through the ALZ policy exception process before tightening enforcement."
  else
    ok "All resources carry the mandatory tags."
  fi
else
  warn "Could not list resources (needs Reader on the subscription)."
fi
echo

ok "Discovery complete. This script made NO changes to your subscription."
