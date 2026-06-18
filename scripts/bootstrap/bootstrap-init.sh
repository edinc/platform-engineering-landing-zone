#!/usr/bin/env bash
#
# bootstrap-init.sh — Stage 01 "secret zero".
#
# Run ONCE, by a Global Administrator, against an empty (or brownfield)
# subscription. Creates the minimum trust chain that lets every later stage run
# from GitHub Actions with no long-lived secrets:
#
#   1. Resource group  rg-pe-tfstate-<loc>
#   2. State storage    stpetf<loc><suffix>   (RA-GRS, TLS1.2, AAD-only)
#   3. Blob container   bootstrap             (this stack's own state)
#   4. Seed Key Vault   kv-pe-boot-<loc>-<sfx> (RBAC, purge protection)
#   5. Entra app + SP + GitHub OIDC federated credential (environment:bootstrap)
#   6. Least-privilege role assignments for the bootstrap deploy identity
#
# The deploy identity is granted NO Microsoft Graph permissions (ADR-0025). It
# prints GitHub Actions *variables* (never secrets) to wire up the workflow.
#
# Idempotent: re-running converges and never fails on already-existing objects.
set -euo pipefail

# --------------------------------------------------------------------------- #
# Logging helpers
# --------------------------------------------------------------------------- #
log()  { printf '\033[0;34m[bootstrap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[  ok  ]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[ warn ]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[fail ]\033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------- #
# Defaults (override with flags)
# --------------------------------------------------------------------------- #
SUBSCRIPTION_ID=""
TENANT_ID=""
NAME_SUFFIX=""
LOCATION="swedencentral"
LOCATION_SHORT="sec"
GITHUB_OWNER="edinc"
GITHUB_REPO="platform-engineering-landing-zone"
ENVIRONMENT="bootstrap"
KEY_VAULT_SKU="standard"
SOFT_DELETE_DAYS="90"
GRANT_ROOT_MG="false"   # opt-in: future tenant-scope work only; Stage 02 does not need it
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage: bootstrap-init.sh --subscription-id <guid> --tenant-id <guid> --name-suffix <2-8 alnum> [options]

Required:
  --subscription-id <guid>   Bootstrap subscription that hosts state + seed Key Vault.
  --tenant-id <guid>         Entra ID tenant.
  --name-suffix <str>        Short, stable, globally-unique disambiguator (2-8 lowercase alnum).

Options:
  --location <region>        Azure region (default: swedencentral).
  --location-short <str>     Name token (default: sec).
  --github-owner <str>       GitHub owner (default: edinc).
  --github-repo <str>        GitHub repo (default: platform-engineering-landing-zone).
  --environment <str>        GitHub Environment for the OIDC subject (default: bootstrap).
  --key-vault-sku <sku>      standard|premium (default: standard).
  --soft-delete-days <n>     Key Vault soft-delete retention (default: 90).
  --grant-root-mg            Also grant the deploy identity Contributor + Resource Policy
                             Contributor at the tenant root management group. Stage 02 does
                             not need this; keep it for explicitly documented future
                             tenant-scope work. Off by default; requires root MG owner/UAA.
  --dry-run                  Print what would happen without changing anything.
  -h, --help                 Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription-id) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --tenant-id)       TENANT_ID="$2"; shift 2 ;;
    --name-suffix)     NAME_SUFFIX="$2"; shift 2 ;;
    --location)        LOCATION="$2"; shift 2 ;;
    --location-short)  LOCATION_SHORT="$2"; shift 2 ;;
    --github-owner)    GITHUB_OWNER="$2"; shift 2 ;;
    --github-repo)     GITHUB_REPO="$2"; shift 2 ;;
    --environment)     ENVIRONMENT="$2"; shift 2 ;;
    --key-vault-sku)   KEY_VAULT_SKU="$2"; shift 2 ;;
    --soft-delete-days) SOFT_DELETE_DAYS="$2"; shift 2 ;;
    --grant-root-mg)   GRANT_ROOT_MG="true"; shift ;;
    --dry-run)         DRY_RUN="true"; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
done

# --------------------------------------------------------------------------- #
# Validation
# --------------------------------------------------------------------------- #
command -v az >/dev/null 2>&1 || die "az CLI is required."
command -v jq >/dev/null 2>&1 || die "jq is required."
[[ -n "$SUBSCRIPTION_ID" ]] || die "--subscription-id is required."
[[ -n "$TENANT_ID" ]]       || die "--tenant-id is required."
[[ -n "$NAME_SUFFIX" ]]     || die "--name-suffix is required."
[[ "$NAME_SUFFIX" =~ ^[a-z0-9]{2,8}$ ]] || die "--name-suffix must be 2-8 lowercase alphanumeric characters."
[[ "$LOCATION_SHORT" =~ ^[a-z0-9]{2,6}$ ]] || die "--location-short must be 2-6 lowercase alphanumeric characters."
[[ "$KEY_VAULT_SKU" =~ ^(standard|premium)$ ]] || die "--key-vault-sku must be standard or premium."

# --------------------------------------------------------------------------- #
# Derived names (must match infrastructure/terraform/_bootstrap/locals.tf)
# --------------------------------------------------------------------------- #
RESOURCE_GROUP="rg-pe-tfstate-${LOCATION_SHORT}"
STORAGE_ACCOUNT="$(printf 'stpetf%s%s' "$LOCATION_SHORT" "$NAME_SUFFIX" | tr '[:upper:]' '[:lower:]')"
KEY_VAULT="kv-pe-boot-${LOCATION_SHORT}-${NAME_SUFFIX}"
STATE_CONTAINER="bootstrap"
APP_NAME="sp-pe-bootstrap-${LOCATION_SHORT}"
OIDC_SUBJECT="repo:${GITHUB_OWNER}/${GITHUB_REPO}:environment:${ENVIRONMENT}"
RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
SA_ID="${RG_ID}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"
KV_ID="${RG_ID}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT}"

[[ ${#STORAGE_ACCOUNT} -le 24 ]] || die "Storage account name '${STORAGE_ACCOUNT}' exceeds 24 characters; shorten --name-suffix or --location-short."
[[ ${#KEY_VAULT} -le 24 ]] || die "Key Vault name '${KEY_VAULT}' exceeds 24 characters; shorten --name-suffix or --location-short."

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '\033[0;90m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

log "Subscription : ${SUBSCRIPTION_ID}"
log "Tenant       : ${TENANT_ID}"
log "Resource grp : ${RESOURCE_GROUP} (${LOCATION})"
log "State account: ${STORAGE_ACCOUNT}"
log "Seed KV      : ${KEY_VAULT}"
log "OIDC subject : ${OIDC_SUBJECT}"
[[ "$DRY_RUN" == "true" ]] && warn "DRY RUN — no changes will be made."

az account set --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1 || \
  die "Cannot select subscription ${SUBSCRIPTION_ID}. Run 'az login --tenant ${TENANT_ID}' first."

CALLER_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
[[ -n "$CALLER_OBJECT_ID" ]] || warn "Could not resolve signed-in user object id; container creation may require an existing data-plane role."

# --------------------------------------------------------------------------- #
# Register the resource providers Terraform needs (subscription-scoped). The
# deploy SP has only resource-group-scoped Contributor and providers.tf sets
# resource_provider_registrations = "none", so the namespaces must be registered
# here (as Global Admin). Without this, the first CI plan/apply on a fresh
# subscription fails at provider configure. Registration completes
# asynchronously; resource creation below tolerates in-flight registration.
# --------------------------------------------------------------------------- #
log "Registering required resource providers ..."
required_rps=(Microsoft.Storage Microsoft.KeyVault Microsoft.ManagedIdentity \
              Microsoft.OperationalInsights Microsoft.Insights Microsoft.Authorization)
for ns in "${required_rps[@]}"; do
  run az provider register --namespace "$ns" >/dev/null 2>&1 ||
    warn "Could not trigger registration for ${ns} (insufficient permission or already registered)."
done
# Registration is asynchronous. Block (bounded) until every namespace reports
# Registered so the first CI plan/apply on a fresh subscription does not fail at
# provider configure. A stuck registration fails loudly rather than hanging.
if [[ "$DRY_RUN" == "false" ]]; then
  log "Waiting for resource providers to finish registering (up to 5m) ..."
  rp_deadline=$(( SECONDS + 300 ))
  for ns in "${required_rps[@]}"; do
    until [[ "$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null)" == "Registered" ]]; do
      if (( SECONDS >= rp_deadline )); then
        die "Resource provider ${ns} did not reach 'Registered' within 5m; register it manually (az provider register --namespace ${ns}) and re-run."
      fi
      sleep 10
    done
  done
fi
ok "Resource providers registered."

# --------------------------------------------------------------------------- #
# 1. Resource group
# --------------------------------------------------------------------------- #
log "Ensuring resource group ${RESOURCE_GROUP} ..."
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  ok "Resource group already exists."
else
  run az group create --name "$RESOURCE_GROUP" --location "$LOCATION" \
    --tags managedBy=terraform product=landing-zone env=platform >/dev/null
  ok "Resource group created."
fi

# --------------------------------------------------------------------------- #
# 2. State storage account (AAD-only, RA-GRS, TLS1.2, infrastructure encryption)
# --------------------------------------------------------------------------- #
# Created with --default-action Allow so this human-run, AAD-authenticated
# bootstrap can create the (empty) state container without firewall-propagation
# races. Data access still requires an Entra token + RBAC (shared-key access is
# disabled), and the FIRST `terraform apply` flips the account to default-deny
# before any real state exists. --require-infrastructure-encryption MUST be set
# here because it is immutable (ForceNew); it has to match state.tf's
# infrastructure_encryption_enabled = true or the first apply would replace the
# account that stores the backend.
log "Ensuring storage account ${STORAGE_ACCOUNT} ..."
if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  ok "Storage account already exists; validating immutable properties (brownfield-safe adoption)."
  sa_json="$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" -o json)"
  [[ "$(jq -r '.encryption.requireInfrastructureEncryption // false' <<<"$sa_json")" == "true" ]] ||
    die "Storage account ${STORAGE_ACCOUNT} has infrastructure encryption disabled, but the stack requires it (immutable). Recreate the account or point the stack at a compliant one before importing."
  [[ "$(jq -r '.kind' <<<"$sa_json")" == "StorageV2" ]] ||
    die "Storage account ${STORAGE_ACCOUNT} is not kind StorageV2 (immutable); cannot adopt it into this stack."
  [[ "$(jq -r '.sku.tier' <<<"$sa_json")" == "Standard" ]] ||
    die "Storage account ${STORAGE_ACCOUNT} is not the Standard tier (immutable); cannot adopt it into this stack."
  [[ "$(jq -r '.isHnsEnabled // false' <<<"$sa_json")" == "false" ]] ||
    die "Storage account ${STORAGE_ACCOUNT} has hierarchical namespace (ADLS Gen2) enabled; flat-blob Terraform state requires a non-HNS account (immutable). Point the stack at a different account."
else
  run az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_RAGRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --https-only true \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --require-infrastructure-encryption true \
    --default-action Allow >/dev/null
  # Created with the network default-action open so the operator's local import/
  # plan can reach the account during adoption; the first 'terraform apply' flips
  # it to Deny with the Phase 1 allowlist. Shared-key access is already disabled,
  # so the data plane still requires Entra + RBAC during this window. Run the
  # first apply promptly (see docs/runbooks/bootstrap.md section 4).
  ok "Storage account created."
fi

log "Enabling blob versioning and soft delete ..."
run az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days "$SOFT_DELETE_DAYS" \
  --enable-container-delete-retention true \
  --container-delete-retention-days "$SOFT_DELETE_DAYS" >/dev/null
ok "Blob data protection configured."

# Grant the operator a data-plane role so the bootstrap container can be created
# with --auth-mode login (shared key access is disabled).
if [[ -n "$CALLER_OBJECT_ID" ]]; then
  log "Granting operator Storage Blob Data Contributor on the state account ..."
  run az role assignment create \
    --assignee-object-id "$CALLER_OBJECT_ID" \
    --assignee-principal-type User \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" >/dev/null 2>&1 || warn "Operator role assignment may already exist."
  if [[ "$DRY_RUN" != "true" ]]; then
    log "Waiting 30s for data-plane RBAC propagation ..."
    sleep 30
  fi
fi

# --------------------------------------------------------------------------- #
# 3. Bootstrap state container
# --------------------------------------------------------------------------- #
log "Ensuring blob container ${STATE_CONTAINER} ..."
if az storage container show --name "$STATE_CONTAINER" --account-name "$STORAGE_ACCOUNT" \
     --auth-mode login >/dev/null 2>&1; then
  ok "Container already exists."
else
  run az storage container create \
    --name "$STATE_CONTAINER" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login >/dev/null
  ok "Container created."
fi

# --------------------------------------------------------------------------- #
# 4. Seed Key Vault (RBAC, purge protection). Recovers a soft-deleted vault of
#    the same name instead of failing on reuse.
# --------------------------------------------------------------------------- #
log "Ensuring seed Key Vault ${KEY_VAULT} ..."
if az keyvault show --name "$KEY_VAULT" >/dev/null 2>&1; then
  ok "Key Vault already exists; validating immutable properties (brownfield-safe adoption)."
  kv_json="$(az keyvault show --name "$KEY_VAULT" -o json)"
  [[ "$(jq -r '.location' <<<"$kv_json")" == "$LOCATION" ]] ||
    die "Key Vault ${KEY_VAULT} is in a different region than ${LOCATION} (immutable); cannot adopt it into this stack."
  [[ "$(jq -r '.properties.tenantId' <<<"$kv_json")" == "$TENANT_ID" ]] ||
    die "Key Vault ${KEY_VAULT} belongs to a different tenant than ${TENANT_ID} (immutable); cannot adopt it."
  [[ "$(jq -r '.properties.sku.name' <<<"$kv_json")" == "$KEY_VAULT_SKU" ]] ||
    die "Key Vault ${KEY_VAULT} SKU is not '${KEY_VAULT_SKU}'; set --key-vault-sku and BOOTSTRAP_KEY_VAULT_SKU to the vault's actual SKU before adoption (a mismatch with a premium HSM vault would drop HSM-backed keys)."
  [[ "$(jq -r '.properties.enableRbacAuthorization // false' <<<"$kv_json")" == "true" ]] ||
    die "Key Vault ${KEY_VAULT} uses access policies, but the stack requires RBAC authorization; migrate it to RBAC (the bootstrap role grants assume RBAC) before adoption."
  kv_softdelete="$(jq -r '.properties.softDeleteRetentionInDays' <<<"$kv_json")"
  [[ "$kv_softdelete" == "$SOFT_DELETE_DAYS" ]] ||
    die "Key Vault ${KEY_VAULT} soft-delete retention is ${kv_softdelete} days but this run targets ${SOFT_DELETE_DAYS} (immutable). Re-run with --soft-delete-days ${kv_softdelete} and set BOOTSTRAP_SOFT_DELETE_DAYS=${kv_softdelete} so Terraform does not attempt a vault recreate."
  [[ "$(jq -r '.properties.enablePurgeProtection // false' <<<"$kv_json")" == "true" ]] ||
    warn "Key Vault ${KEY_VAULT} does not have purge protection enabled; Terraform will enable it (this cannot be reverted)."
elif az keyvault list-deleted --query "[?name=='${KEY_VAULT}'] | [0].name" -o tsv 2>/dev/null | grep -q "$KEY_VAULT"; then
  warn "A soft-deleted Key Vault named ${KEY_VAULT} exists; recovering it."
  run az keyvault recover --name "$KEY_VAULT" >/dev/null
  ok "Key Vault recovered."
else
  run az keyvault create \
    --name "$KEY_VAULT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "$KEY_VAULT_SKU" \
    --enable-rbac-authorization true \
    --enable-purge-protection true \
    --retention-days "$SOFT_DELETE_DAYS" >/dev/null
  ok "Key Vault created."
fi

# --------------------------------------------------------------------------- #
# 5. Entra application + service principal + GitHub OIDC federated credential
# --------------------------------------------------------------------------- #
log "Ensuring Entra application ${APP_NAME} ..."
# Entra display names are NOT unique, and any tenant member can register an app
# with this script's well-known name. Match exactly (OData filter) and refuse if
# more than one app shares the name; when exactly one exists, adopt it ONLY after
# the provenance gate below proves it is the app this script created (idempotent
# re-run). Otherwise create a fresh app. Name matching alone does not establish
# provenance, so adoption is additionally guarded by an ownership + credential
# check before any service principal or role assignment is attached.
app_matches_json="$(az ad app list --filter "displayName eq '${APP_NAME}'" -o json 2>/dev/null || echo '[]')"
app_match_count="$(jq 'length' <<<"$app_matches_json")"
[[ "$app_match_count" -le 1 ]] ||
  die "Found ${app_match_count} Entra applications named '${APP_NAME}'. Display names are not unique; remove or rename the duplicates (or adopt the intended one manually) before re-running."
APP_ID="$(jq -r '.[0].appId // empty' <<<"$app_matches_json")"
if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    APP_ID="00000000-0000-0000-0000-000000000000"
    printf '\033[0;90m[dry-run]\033[0m az ad app create --display-name %s\n' "$APP_NAME"
  else
    APP_ID="$(az ad app create --display-name "$APP_NAME" \
      --sign-in-audience AzureADMyOrg --query appId -o tsv)"
  fi
  ok "Application created (appId ${APP_ID})."
else
  # SECURITY: provenance gate. A single name match is adopted only if it is
  # provably the app THIS script created, never a name-squat. We require the
  # signed-in operator to be the SOLE owner (creating an app makes its creator
  # the sole owner; a planted app carries a foreign owner) AND the app to carry
  # no client secrets / certificates (this bootstrap is OIDC-only) and only
  # federated credentials that match BOTH our GitHub Actions issuer and our exact
  # subject. The issuer is the real trust anchor: a credential carrying our
  # subject but a foreign issuer would let an attacker-controlled IdP mint tokens
  # for this identity, so subject-only matching is insufficient. Every read fails
  # closed: if provenance cannot be confirmed we refuse rather than attach
  # Contributor + User Access Administrator on the state RG to an unknown identity.
  [[ -n "$CALLER_OBJECT_ID" ]] ||
    die "Cannot verify ownership of existing application '${APP_NAME}' (appId ${APP_ID}): no signed-in user object id. Re-run as the human operator, or remove the app, before adopting it."
  app_owners="$(az ad app owner list --id "$APP_ID" --query "[].id" -o tsv 2>/dev/null)" ||
    die "Could not read owners of existing application '${APP_NAME}' (appId ${APP_ID}); refusing to adopt without verifying provenance."
  [[ "$app_owners" == "$CALLER_OBJECT_ID" ]] ||
    die "Refusing to adopt existing application '${APP_NAME}' (appId ${APP_ID}): the signed-in operator (${CALLER_OBJECT_ID}) is not its sole owner. This is a possible name-squat; verify the app's provenance and make the operator its sole owner, or remove the app, before re-running."
  app_secret_count="$(az ad app credential list --id "$APP_ID" --query 'length(@)' -o tsv 2>/dev/null)" ||
    die "Could not enumerate client secrets on existing application '${APP_NAME}' (appId ${APP_ID}); refusing to adopt without verifying provenance."
  app_cert_count="$(az ad app credential list --id "$APP_ID" --cert --query 'length(@)' -o tsv 2>/dev/null)" ||
    die "Could not enumerate certificates on existing application '${APP_NAME}' (appId ${APP_ID}); refusing to adopt without verifying provenance."
  app_foreign_fic="$(az ad app federated-credential list --id "$APP_ID" --query "[?subject!='${OIDC_SUBJECT}' || issuer!='https://token.actions.githubusercontent.com'] | length(@)" -o tsv 2>/dev/null)" ||
    die "Could not enumerate federated credentials on existing application '${APP_NAME}' (appId ${APP_ID}); refusing to adopt without verifying provenance."
  [[ "${app_secret_count:-1}" -eq 0 && "${app_cert_count:-1}" -eq 0 && "${app_foreign_fic:-1}" -eq 0 ]] ||
    die "Refusing to adopt existing application '${APP_NAME}' (appId ${APP_ID}): it carries foreign credentials (client secrets=${app_secret_count}, certificates=${app_cert_count}, non-bootstrap federated credentials=${app_foreign_fic}). This bootstrap creates OIDC federated credentials only, with issuer 'https://token.actions.githubusercontent.com' and subject '${OIDC_SUBJECT}'; any other credential indicates a different application. Verify provenance or remove the app before re-running."
  ok "Application already exists; provenance verified (appId ${APP_ID})."
fi

log "Ensuring service principal ..."
SP_OBJECT_ID="$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[0].id" -o tsv 2>/dev/null || true)"
if [[ -z "$SP_OBJECT_ID" || "$SP_OBJECT_ID" == "null" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    SP_OBJECT_ID="00000000-0000-0000-0000-000000000000"
    printf '\033[0;90m[dry-run]\033[0m az ad sp create --id %s\n' "$APP_ID"
  else
    SP_OBJECT_ID="$(az ad sp create --id "$APP_ID" --query id -o tsv)"
  fi
  ok "Service principal created (objectId ${SP_OBJECT_ID})."
else
  ok "Service principal already exists (objectId ${SP_OBJECT_ID})."
fi

log "Ensuring GitHub OIDC federated credential (subject ${OIDC_SUBJECT}) ..."
FIC_NAME="github-${GITHUB_REPO}-${ENVIRONMENT}"
if az ad app federated-credential list --id "$APP_ID" \
     --query "[?subject=='${OIDC_SUBJECT}'] | [0].name" -o tsv 2>/dev/null | grep -q .; then
  ok "Federated credential already exists."
else
  fic_json="$(jq -n \
    --arg name "$FIC_NAME" \
    --arg subject "$OIDC_SUBJECT" \
    '{name: $name, issuer: "https://token.actions.githubusercontent.com", subject: $subject, audiences: ["api://AzureADTokenExchange"]}')"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '\033[0;90m[dry-run]\033[0m az ad app federated-credential create --id %s --parameters %s\n' "$APP_ID" "$fic_json"
  else
    az ad app federated-credential create --id "$APP_ID" --parameters "$fic_json" >/dev/null
  fi
  ok "Federated credential created."
fi

# --------------------------------------------------------------------------- #
# 6. Least-privilege role assignments for the deploy identity.
#    NO Microsoft Graph permissions are granted (ADR-0025).
# --------------------------------------------------------------------------- #
assign_role() {
  local role="$1" scope="$2"
  log "Assigning '${role}' on ${scope##*/} ..."
  run az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope" >/dev/null 2>&1 || warn "Role '${role}' may already be assigned."
}

assign_role "Contributor"                      "$RG_ID"   # manage RG, SA, KV, monitoring
assign_role "User Access Administrator"        "$RG_ID"   # manage the UAMI->KV role assignment (RG-scoped, ADR-0025)
assign_role "Storage Blob Data Contributor"    "$SA_ID"   # read/write Terraform state blobs
assign_role "Key Vault Crypto Officer"         "$KV_ID"   # create/rotate the state CMK
assign_role "Key Vault Secrets Officer"        "$KV_ID"   # manage bootstrap secrets

if [[ "$GRANT_ROOT_MG" == "true" ]]; then
  ROOT_MG_ID="/providers/Microsoft.Management/managementGroups/${TENANT_ID}"
  warn "Granting root management group roles (opt-in) at ${ROOT_MG_ID}."
  assign_role "Contributor"                    "$ROOT_MG_ID"
  assign_role "Resource Policy Contributor"    "$ROOT_MG_ID"
else
  log "Skipping root management group roles (Stage 02 does not need them; enable --grant-root-mg only for explicitly documented future tenant-scope work)."
fi

# --------------------------------------------------------------------------- #
# Output: GitHub Actions VARIABLES (not secrets) and backend settings
# --------------------------------------------------------------------------- #
cat <<EOF

$(ok "Bootstrap complete.")

Set the following GitHub Actions *variables* (Settings > Secrets and variables >
Actions > Variables, or environment '${ENVIRONMENT}'). These are NOT secrets —
OIDC means there is nothing sensitive to store:

  AZURE_CLIENT_ID         ${APP_ID}
  AZURE_TENANT_ID         ${TENANT_ID}
  AZURE_SUBSCRIPTION_ID   ${SUBSCRIPTION_ID}
  TFSTATE_RESOURCE_GROUP  ${RESOURCE_GROUP}
  TFSTATE_STORAGE_ACCOUNT ${STORAGE_ACCOUNT}
  TFSTATE_CONTAINER       ${STATE_CONTAINER}
  BOOTSTRAP_NAME_SUFFIX   ${NAME_SUFFIX}
  BOOTSTRAP_LOCATION      ${LOCATION}
  BOOTSTRAP_LOCATION_SHORT ${LOCATION_SHORT}
  BOOTSTRAP_SOFT_DELETE_DAYS ${SOFT_DELETE_DAYS}

With the GitHub CLI:

  gh variable set AZURE_CLIENT_ID         --env ${ENVIRONMENT} --body "${APP_ID}"
  gh variable set AZURE_TENANT_ID         --env ${ENVIRONMENT} --body "${TENANT_ID}"
  gh variable set AZURE_SUBSCRIPTION_ID   --env ${ENVIRONMENT} --body "${SUBSCRIPTION_ID}"
  gh variable set TFSTATE_RESOURCE_GROUP  --env ${ENVIRONMENT} --body "${RESOURCE_GROUP}"
  gh variable set TFSTATE_STORAGE_ACCOUNT --env ${ENVIRONMENT} --body "${STORAGE_ACCOUNT}"
  gh variable set TFSTATE_CONTAINER       --env ${ENVIRONMENT} --body "${STATE_CONTAINER}"
  gh variable set BOOTSTRAP_NAME_SUFFIX   --env ${ENVIRONMENT} --body "${NAME_SUFFIX}"
  gh variable set BOOTSTRAP_LOCATION      --env ${ENVIRONMENT} --body "${LOCATION}"
  gh variable set BOOTSTRAP_LOCATION_SHORT --env ${ENVIRONMENT} --body "${LOCATION_SHORT}"
  gh variable set BOOTSTRAP_SOFT_DELETE_DAYS --env ${ENVIRONMENT} --body "${SOFT_DELETE_DAYS}"

BOOTSTRAP_SOFT_DELETE_DAYS is REQUIRED and MUST equal this run's --soft-delete-days
(${SOFT_DELETE_DAYS}): it is immutable on the Key Vault, so a mismatch forces a vault
recreate that purge protection blocks. The workflow passes it straight through and
fails fast if it is unset.

Optional persistent Terraform inputs — the workflow maps each to a TF_VAR_* only
when set. allowed_ip_cidrs is the STANDING break-glass operator allowlist (use a
bare IP for a single host, never /32, which the storage firewall normalizes and
would show a permanent diff); the two break-glass variables enable the sign-in
alert:

  gh variable set BOOTSTRAP_ALLOWED_IP_CIDRS      --env ${ENVIRONMENT} --body '["203.0.113.10"]'
  gh variable set BOOTSTRAP_BREAK_GLASS_UPNS      --env ${ENVIRONMENT} --body '["breakglass-1@contoso.onmicrosoft.com"]'
  gh variable set BOOTSTRAP_ALERT_EMAIL_RECEIVERS --env ${ENVIRONMENT} --body '["platform-oncall@example.com"]'

This run created the seed Key Vault with the '${KEY_VAULT_SKU}' SKU. If you chose
--key-vault-sku premium for an HSM-backed CMK, you MUST set both variables below so
CI does not converge the stack back to the standard / RSA defaults (key_type is
immutable on the CMK key, so a mismatch forces a destructive key recreate):

  gh variable set BOOTSTRAP_KEY_VAULT_SKU --env ${ENVIRONMENT} --body '${KEY_VAULT_SKU}'
  gh variable set BOOTSTRAP_KEY_TYPE      --env ${ENVIRONMENT} --body 'RSA-HSM'

Local backend.hcl (infrastructure/terraform/_bootstrap/backend.hcl):

  resource_group_name  = "${RESOURCE_GROUP}"
  storage_account_name = "${STORAGE_ACCOUNT}"
  container_name       = "${STATE_CONTAINER}"
  key                  = "bootstrap.tfstate"
  use_azuread_auth     = true

Next: adopt these resources into Terraform with 'make bootstrap-import', then
'make bootstrap-plan' / 'make bootstrap-apply'. See docs/runbooks/bootstrap.md.
EOF
