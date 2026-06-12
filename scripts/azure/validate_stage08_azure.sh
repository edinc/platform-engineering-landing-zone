#!/usr/bin/env bash
set -euo pipefail

missing=()
for tool in az jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then missing+=("$tool"); fi
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "ERROR: Missing required Azure CLI tools: ${missing[*]}" >&2
  exit 1
fi

if [ -n "${AZURE_SUBSCRIPTION_ID:-}" ]; then
  az account set --subscription "$AZURE_SUBSCRIPTION_ID"
fi

subscription_id="$(az account show --query id -o tsv)"
if [ -z "$subscription_id" ]; then
  echo "ERROR: Azure CLI is not logged in. Run az login or use workload identity/OIDC." >&2
  exit 1
fi

required_env=(
  STAGE08_PLATFORM_RESOURCE_GROUP
  STAGE08_AKS_NAME
  STAGE08_ACTION_GROUP_SEV1
  STAGE08_COST_EXPORT_NAME
)
for name in "${required_env[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "ERROR: $name is required for Stage 08 Azure validation." >&2
    exit 1
  fi
done

cost_scope="${STAGE08_COST_EXPORT_SCOPE:-/subscriptions/${subscription_id}}"

echo "Validating Stage 08 resources in subscription ${subscription_id}"

aks_state="$(az aks show \
  --resource-group "$STAGE08_PLATFORM_RESOURCE_GROUP" \
  --name "$STAGE08_AKS_NAME" \
  --query "[nodeProvisioningProfile.mode, azureMonitorProfile.metrics.enabled]" \
  -o tsv)"
node_provisioning_mode="$(awk 'NR==1 {print $1}' <<< "$aks_state")"
managed_prometheus_enabled="$(awk 'NR==1 {print $2}' <<< "$aks_state")"
if [ "${STAGE08_EXPECT_NAP_AUTO:-true}" = "true" ] && [ "$node_provisioning_mode" != "Auto" ]; then
  echo "ERROR: AKS nodeProvisioningProfile.mode is '$node_provisioning_mode', expected Auto." >&2
  exit 1
fi
if [ "$managed_prometheus_enabled" != "true" ]; then
  echo "ERROR: AKS Managed Prometheus is '$managed_prometheus_enabled', expected true." >&2
  exit 1
fi
printf 'AKS\t%s\t%s\n' "$node_provisioning_mode" "$managed_prometheus_enabled"

az k8s-extension list \
  --cluster-type managedClusters \
  --cluster-name "$STAGE08_AKS_NAME" \
  --resource-group "$STAGE08_PLATFORM_RESOURCE_GROUP" \
  --query "[?extensionType=='microsoft.flux'].{name:name,provisioningState:provisioningState}" \
  -o table

action_group_state="$(az monitor action-group show \
  --resource-group "$STAGE08_PLATFORM_RESOURCE_GROUP" \
  --name "$STAGE08_ACTION_GROUP_SEV1" \
  --query "{name:name,enabled:enabled,emailReceivers:length(emailReceivers),webhookReceivers:length(webhookReceivers),itsmReceivers:length(itsmReceivers)}" \
  -o json)"
action_group_enabled="$(jq -r '.enabled' <<< "$action_group_state")"
receiver_count="$(jq '[.emailReceivers, .webhookReceivers, .itsmReceivers] | add' <<< "$action_group_state")"
if [ "$action_group_enabled" != "true" ]; then
  echo "ERROR: SEV1 Action Group is not enabled." >&2
  exit 1
fi
if [ "$receiver_count" -lt 1 ]; then
  echo "ERROR: SEV1 Action Group has no receivers." >&2
  exit 1
fi
echo "$action_group_state" | jq -r '[.name, .enabled, .emailReceivers, .webhookReceivers, .itsmReceivers] | @tsv'

cost_export_state="$(az costmanagement export show \
  --scope "$cost_scope" \
  --name "$STAGE08_COST_EXPORT_NAME" \
  --query "{name:name,type:definition.type,timeframe:definition.timeframe,recurrence:schedule.recurrence}" \
  -o json)"
if [ "$(jq -r '.type' <<< "$cost_export_state")" != "ActualCost" ]; then
  echo "ERROR: Cost export type is not ActualCost." >&2
  exit 1
fi
if [ "$(jq -r '.recurrence' <<< "$cost_export_state")" != "Daily" ]; then
  echo "ERROR: Cost export recurrence is not Daily." >&2
  exit 1
fi
echo "$cost_export_state" | jq -r '[.name, .type, .timeframe, .recurrence] | @tsv'

if [ -n "${STAGE08_FUNCTION_APP_NAME:-}" ]; then
  function_state="$(az functionapp show \
    --resource-group "$STAGE08_PLATFORM_RESOURCE_GROUP" \
    --name "$STAGE08_FUNCTION_APP_NAME" \
    --query "{name:name,state:state,httpsOnly:httpsOnly,identity:identity.type}" \
    -o json)"
  if [ "$(jq -r '.httpsOnly' <<< "$function_state")" != "true" ]; then
    echo "ERROR: Cost allocator Function App does not enforce HTTPS-only." >&2
    exit 1
  fi
  if [ "$(jq -r '.identity' <<< "$function_state")" != "SystemAssigned" ]; then
    echo "ERROR: Cost allocator Function App does not use a system-assigned managed identity." >&2
    exit 1
  fi
  echo "$function_state" | jq -r '[.name, .state, .httpsOnly, .identity] | @tsv'
fi
