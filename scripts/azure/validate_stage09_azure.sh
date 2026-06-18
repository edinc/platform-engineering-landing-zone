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

if command -v curl >/dev/null 2>&1; then
  curl --fail --silent --show-error --max-time 10 "https://${BACKSTAGE_HOST}/.backstage/health/v1/readiness" >/dev/null
  echo "Backstage readiness endpoint responded successfully."
else
  echo "curl is not installed; skipped Backstage HTTPS health check."
fi
