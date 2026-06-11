#!/usr/bin/env bash
#
# Import existing Defender for Cloud subscription pricing resources into the
# Stage 02 subscription-baseline Terraform state. Brownfield subscriptions often
# already have Standard pricing enabled; azurerm requires those resources to be
# imported before apply can manage them.
set -euo pipefail

log() { printf '\033[0;34m[defender-import]\033[0m %s\n' "$*"; }
ok()  { printf '\033[0;32m[      ok      ]\033[0m %s\n' "$*"; }
die() { printf '\033[0;31m[     fail     ]\033[0m %s\n' "$*" >&2; exit 1; }

STACK_DIR="infrastructure/terraform/subscription-baseline"
SUBSCRIPTION_ID=""

usage() {
  cat <<'USAGE'
Usage: scripts/subscription/import-defender-pricing.sh --subscription-id <guid> [--stack-dir <path>]

Run after `terraform init` for infrastructure/terraform/subscription-baseline and
before the first apply against a brownfield subscription with existing Defender
pricing tiers.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription-id) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --stack-dir) STACK_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ "$SUBSCRIPTION_ID" =~ ^[0-9a-fA-F-]{36}$ ]] || die "--subscription-id must be a GUID."
[[ -d "$STACK_DIR" ]] || die "Stack directory not found: $STACK_DIR"

resource_types=(
  Api
  Arm
  Containers
  KeyVaults
  OpenSourceRelationalDatabases
  SqlServers
  StorageAccounts
  VirtualMachines
)

cd "$STACK_DIR"
terraform state list >/dev/null

for resource_type in "${resource_types[@]}"; do
  address="azurerm_security_center_subscription_pricing.this[\"${resource_type}\"]"
  id="/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Security/pricings/${resource_type}"
  if terraform state list | grep -qxF "$address"; then
    ok "Already in state: ${resource_type}"
    continue
  fi
  log "Importing ${resource_type} pricing ..."
  terraform import -input=false "$address" "$id"
  ok "Imported ${resource_type}"
done
