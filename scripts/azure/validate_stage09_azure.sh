#!/usr/bin/env bash
set -euo pipefail

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

az aks show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name "$PLATFORM_AKS_CLUSTER_NAME" \
  --query "{name:name, oidc:oidcIssuerProfile.enabled, workloadIdentity:securityProfile.workloadIdentity.enabled}" \
  --output table

az storage account show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name "$TECHDOCS_STORAGE_ACCOUNT_NAME" \
  --query "{name:name, publicNetworkAccess:publicNetworkAccess, allowBlobPublicAccess:allowBlobPublicAccess, sharedKeyAccess:allowSharedKeyAccess, minTls:minimumTlsVersion}" \
  --output table

az storage container exists \
  --auth-mode login \
  --account-name "$TECHDOCS_STORAGE_ACCOUNT_NAME" \
  --name "${TECHDOCS_STORAGE_CONTAINER_NAME:-techdocs}" \
  --query "exists" \
  --output tsv

az network private-endpoint list \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --query "[?contains(privateLinkServiceConnections[0].privateLinkServiceId, '${TECHDOCS_STORAGE_ACCOUNT_NAME}')].{name:name, state:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
  --output table

if command -v curl >/dev/null 2>&1; then
  curl --fail --silent --show-error --max-time 10 "https://${BACKSTAGE_HOST}/.backstage/health/v1/readiness" >/dev/null
  echo "Backstage readiness endpoint responded successfully."
else
  echo "curl is not installed; skipped Backstage HTTPS health check."
fi
