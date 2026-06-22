#!/usr/bin/env bash
set -euo pipefail

missing_tools=()
for tool in az curl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done
if [ "${#missing_tools[@]}" -gt 0 ]; then
  echo "Missing required tools: ${missing_tools[*]}" >&2
  exit 1
fi

required=(
  AZURE_SUBSCRIPTION_ID
  PLATFORM_RESOURCE_GROUP_NAME
  PLATFORM_AKS_CLUSTER_NAME
  TECHDOCS_STORAGE_ACCOUNT_NAME
  BACKSTAGE_HOST
)

missing=()
for name in "${required[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required environment variables: ${missing[*]}" >&2
  echo "This read-only check expects deployed Stage 09 resource names; no Azure resources were modified." >&2
  exit 2
fi

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

aks_state="$(az aks show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name "$PLATFORM_AKS_CLUSTER_NAME" \
  --query "{name:name, oidc:oidcIssuerProfile.enabled, workloadIdentity:securityProfile.workloadIdentity.enabled}" \
  --output json)"
if [ "$(jq -r '.oidc' <<< "$aks_state")" != "true" ]; then
  echo "AKS OIDC issuer is not enabled." >&2
  exit 1
fi
if [ "$(jq -r '.workloadIdentity' <<< "$aks_state")" != "true" ]; then
  echo "AKS Workload Identity is not enabled." >&2
  exit 1
fi
echo "$aks_state" | jq -r '[.name, .oidc, .workloadIdentity] | @tsv'

storage_state="$(az storage account show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name "$TECHDOCS_STORAGE_ACCOUNT_NAME" \
  --query "{name:name, publicNetworkAccess:publicNetworkAccess, allowBlobPublicAccess:allowBlobPublicAccess, sharedKeyAccess:allowSharedKeyAccess, minTls:minimumTlsVersion}" \
  --output json)"
if [ "$(jq -r '.publicNetworkAccess' <<< "$storage_state")" != "Disabled" ]; then
  echo "TechDocs storage public network access is not disabled." >&2
  exit 1
fi
if [ "$(jq -r '.allowBlobPublicAccess' <<< "$storage_state")" != "false" ]; then
  echo "TechDocs storage allows blob public access." >&2
  exit 1
fi
if [ "$(jq -r '.sharedKeyAccess' <<< "$storage_state")" != "false" ]; then
  echo "TechDocs storage shared key access is not disabled." >&2
  exit 1
fi
if [ "$(jq -r '.minTls' <<< "$storage_state")" != "TLS1_2" ]; then
  echo "TechDocs storage minimum TLS is not TLS1_2." >&2
  exit 1
fi
echo "$storage_state" | jq -r '[.name, .publicNetworkAccess, .allowBlobPublicAccess, .sharedKeyAccess, .minTls] | @tsv'

container_exists="$(az storage container exists \
  --auth-mode login \
  --account-name "$TECHDOCS_STORAGE_ACCOUNT_NAME" \
  --name "${TECHDOCS_STORAGE_CONTAINER_NAME:-techdocs}" \
  --query "exists" \
  --output tsv)"
if [ "$container_exists" != "true" ]; then
  echo "TechDocs storage container ${TECHDOCS_STORAGE_CONTAINER_NAME:-techdocs} does not exist." >&2
  exit 1
fi
echo "TechDocs container exists."

private_endpoint_count="$(az network private-endpoint list \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --query "[?contains(privateLinkServiceConnections[0].privateLinkServiceId, '${TECHDOCS_STORAGE_ACCOUNT_NAME}') && privateLinkServiceConnections[0].privateLinkServiceConnectionState.status == 'Approved'] | length(@)" \
  --output tsv)"
if [ "$private_endpoint_count" -lt 1 ]; then
  echo "No approved TechDocs private endpoint found in $PLATFORM_RESOURCE_GROUP_NAME." >&2
  exit 1
fi
echo "Approved TechDocs private endpoints: $private_endpoint_count"

curl_args=(--fail --silent --show-error --max-time 10)
ca_file=""
if [ -n "${BACKSTAGE_RESOLVE_IP:-}" ]; then
  curl_args+=(--resolve "${BACKSTAGE_HOST}:443:${BACKSTAGE_RESOLVE_IP}")
  echo "Backstage readiness resolves ${BACKSTAGE_HOST} to ${BACKSTAGE_RESOLVE_IP} for this private smoke."
fi
case "${BACKSTAGE_TRUST_PRIVATE_CA:-false}" in
  true|TRUE|1)
    if [ -z "${BACKSTAGE_TLS_CA_KEY_VAULT_NAME:-}" ]; then
      echo "BACKSTAGE_TLS_CA_KEY_VAULT_NAME is required when BACKSTAGE_TRUST_PRIVATE_CA is true." >&2
      exit 2
    fi
    ca_file="$(mktemp)"
    trap 'rm -f "$ca_file"' EXIT
    az keyvault secret show \
      --vault-name "$BACKSTAGE_TLS_CA_KEY_VAULT_NAME" \
      --name "${BACKSTAGE_TLS_CA_SECRET_NAME:-platform-private-ca-crt}" \
      --query value \
      --output tsv > "$ca_file"
    if ! grep -q "BEGIN CERTIFICATE" "$ca_file"; then
      echo "Backstage TLS CA secret ${BACKSTAGE_TLS_CA_SECRET_NAME:-platform-private-ca-crt} does not contain a PEM certificate." >&2
      exit 1
    fi
    curl_args+=(--cacert "$ca_file")
    echo "Backstage readiness TLS verification uses private CA from Key Vault."
    ;;
  false|FALSE|0|"")
    ;;
  *)
    echo "BACKSTAGE_TRUST_PRIVATE_CA must be true or false." >&2
    exit 2
    ;;
esac

if [ -n "${BACKSTAGE_CLUSTER_READINESS:-}" ] && [ "${BACKSTAGE_CLUSTER_READINESS}" != "false" ]; then
  az aks command invoke \
    --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
    --name "$PLATFORM_AKS_CLUSTER_NAME" \
    --command "kubectl -n backstage exec deploy/backstage -- node -e \"fetch('http://127.0.0.1:7007/.backstage/health/v1/readiness').then(r=>{if(!r.ok){console.error('status '+r.status);process.exit(1)}}).catch(e=>{console.error(e);process.exit(1)})\"" \
    --query logs \
    --output tsv >/dev/null
  echo "Backstage in-cluster readiness endpoint responded successfully."
else
  curl "${curl_args[@]}" "https://${BACKSTAGE_HOST}/.backstage/health/v1/readiness" >/dev/null
fi
echo "Backstage readiness endpoint responded successfully."
