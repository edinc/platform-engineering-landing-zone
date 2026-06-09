#!/usr/bin/env bash
#
# bootstrap-import.sh — adopt the resources created by bootstrap-init.sh into the
# _bootstrap Terraform state. Run ONCE, after 'make bootstrap-init', before the
# first 'make bootstrap-apply'. Idempotent: resources already in state are
# skipped, so re-running is safe and a no-op once adoption is complete.
#
# Inputs are read from infrastructure/terraform/_bootstrap/terraform.tfvars and
# may be overridden by environment variables:
#   SUBSCRIPTION_ID, LOCATION_SHORT, NAME_SUFFIX
set -euo pipefail

log()  { printf '\033[0;34m[import]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[  ok  ]\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m[fail ]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STACK_DIR="${REPO_ROOT}/infrastructure/terraform/_bootstrap"
TFVARS="${STACK_DIR}/terraform.tfvars"

command -v terraform >/dev/null 2>&1 || die "terraform is required."

# Extract a scalar string value from terraform.tfvars (simple key = "value").
tfvar() {
  local key="$1"
  [[ -f "$TFVARS" ]] || return 0
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$TFVARS" | head -n1
}

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(tfvar subscription_id)}"
LOCATION_SHORT="${LOCATION_SHORT:-$(tfvar location_short)}"
NAME_SUFFIX="${NAME_SUFFIX:-$(tfvar name_suffix)}"
LOCATION_SHORT="${LOCATION_SHORT:-weu}"

[[ -n "$SUBSCRIPTION_ID" ]] || die "SUBSCRIPTION_ID not set and not found in ${TFVARS}."
[[ -n "$NAME_SUFFIX" ]]     || die "NAME_SUFFIX not set and not found in ${TFVARS}."

RESOURCE_GROUP="rg-pe-tfstate-${LOCATION_SHORT}"
STORAGE_ACCOUNT="$(printf 'stpetf%s%s' "$LOCATION_SHORT" "$NAME_SUFFIX" | tr '[:upper:]' '[:lower:]')"
KEY_VAULT="kv-pe-boot-${LOCATION_SHORT}-${NAME_SUFFIX}"

RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
SA_ID="${RG_ID}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"
CONTAINER_ID="${SA_ID}/blobServices/default/containers/bootstrap"
KV_ID="${RG_ID}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT}"

cd "$STACK_DIR"

[[ -f .terraform/terraform.tfstate || -d .terraform ]] || \
  die "Backend not initialized. Run 'make bootstrap-tf-init' first."

# Import one address if it is not already tracked in state.
import_once() {
  local address="$1" id="$2"
  if terraform state list 2>/dev/null | grep -qxF "$address"; then
    ok "Already in state: ${address}"
    return 0
  fi
  log "Importing ${address} ..."
  terraform import -input=false "$address" "$id"
  ok "Imported ${address}"
}

import_once 'azurerm_resource_group.tfstate'           "$RG_ID"
import_once 'azurerm_storage_account.tfstate'          "$SA_ID"
import_once 'azurerm_storage_container.stage["bootstrap"]' "$CONTAINER_ID"
import_once 'azurerm_key_vault.bootstrap'              "$KV_ID"

ok "Adoption complete. Review with 'make bootstrap-plan' before applying."
