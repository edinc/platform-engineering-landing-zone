#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "${ROOT}/.tools/tmp"
TMP_DIR="$(mktemp -d "${ROOT}/.tools/tmp/stage10-onboarding-smoke.XXXXXX")"
ALLOWLIST="${ROOT}/policies/azure/firewall/allowlist.json"
EGRESS_PATCH_DIR="${TMP_DIR}/exception-patches"
EGRESS_POLICY_DIR="${TMP_DIR}/overlays/demo/network/egress-exceptions"
EGRESS_KUSTOMIZATION="${EGRESS_POLICY_DIR}/kustomization.yaml"

mkdir -p "$TMP_DIR" "$EGRESS_PATCH_DIR" "$EGRESS_POLICY_DIR"
cp "$ALLOWLIST" "${TMP_DIR}/allowlist.json"
cat > "$EGRESS_KUSTOMIZATION" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
YAML
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Validating Stage 10 repository contracts..."
python3 "${ROOT}/scripts/backstage/validate_stage10_multitenancy.py"

echo "Validating TeamOnboardingRequest example..."
ruby -rjson -ryaml -e 'puts JSON.pretty_generate(YAML.safe_load_file(ARGV.fetch(0), aliases: false))' \
  "${ROOT}/docs/contracts/examples/team-onboarding-request.yaml" > "${TMP_DIR}/team-request.json"
python3 "${ROOT}/scripts/workflows/validate_team_onboarding_request.py" "${TMP_DIR}/team-request.json"

cat > "${TMP_DIR}/namespace-object-id.yaml" <<'YAML'
apiVersion: platform.example.io/v1alpha1
kind: NamespaceVendingRequest
metadata:
  name: payments-checkout-demo
spec:
  team: payments
  product: checkout
  costCenter: cc-payments
  onCallRotationId: pd-payments-primary
  dataClassification: confidential
  environment: demo
  regions:
    - westeurope
  tags:
    owner: payments
    costCenter: cc-payments
    product: checkout
    dataClassification: confidential
    confidentiality: medium
    managedBy: terraform
    repo: edinc/platform-engineering-landing-zone
  namespace:
    name: payments-checkout-demo
    clusterEnvironment: demo
    entraGroupObjectId: 00000000-0000-0000-0000-000000000001
    serviceAccountName: checkout-api
    resourceQuota:
      cpuRequests: "1000m"
      memoryRequests: 2Gi
      cpuLimits: "2000m"
      memoryLimits: 4Gi
      pods: 25
    egressAllowlist:
      cidrs:
        - 10.30.0.0/16
    azure:
      aksClusterId: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pe-demo-platform-weu/providers/Microsoft.ContainerService/managedClusters/aks-pe-demo-weu
      acrId: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-pe-demo-platform-weu/providers/Microsoft.ContainerRegistry/registries/acrpedemoweu001
      keyVaultSecretIds: []
      resourceGroupName: rg-pe-demo-platform-weu
YAML

echo "Validating NamespaceVendingRequest object-id contract..."
ruby -rjson -ryaml -e 'puts JSON.pretty_generate(YAML.safe_load_file(ARGV.fetch(0), aliases: false))' \
  "${TMP_DIR}/namespace-object-id.yaml" > "${TMP_DIR}/namespace-object-id.json"
STAGE10_SMOKE_TMP_DIR="$TMP_DIR" python3 - <<'PY'
import json
import os
from pathlib import Path

tmp_dir = Path(os.environ["STAGE10_SMOKE_TMP_DIR"])
request = json.loads((tmp_dir / "namespace-object-id.json").read_text())
assert request["kind"] == "NamespaceVendingRequest"
assert request["spec"]["namespace"]["entraGroupObjectId"]
assert request["spec"]["namespace"]["azure"]["keyVaultSecretIds"] == []
assert request["spec"]["namespace"]["clusterEnvironment"] == request["spec"]["environment"]
print("NamespaceVendingRequest smoke fixture validated.")
PY

echo "Validating egress exception patch wiring..."
expires_on="$(python3 - <<'PY'
from datetime import date, timedelta
print((date.today() + timedelta(days=30)).isoformat())
PY
)"
cat > "${EGRESS_PATCH_DIR}/stage10-smoke-egress.json" <<EOF
{
  "collection": {
    "name": "team-stage10-smoke-egress",
    "priority": 899,
    "action": "Allow",
    "rules": [
      {
        "name": "stage10-smoke-egress",
        "destination_fqdns": [
          "api.example.com"
        ],
        "protocols": [
          {
            "type": "Https",
            "port": 443
          }
        ]
      }
    ],
    "metadata": {
      "team": "stage10",
      "namespace": "stage10-smoke-demo",
      "dataClassification": "internal",
      "expiresOn": "${expires_on}",
      "businessJustification": "Stage 10 smoke test fixture"
    }
  },
  "applyTo": "policies/azure/firewall/allowlist.json"
}
EOF
cat > "${EGRESS_POLICY_DIR}/stage10-smoke-egress.yaml" <<YAML
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: egress-stage10-smoke-egress
  namespace: stage10-smoke-demo
  labels:
    platform.example.io/team: stage10
  annotations:
    platform.example.io/expires-on: "${expires_on}"
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: smoke
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchName: "api.example.com"
    - toFQDNs:
        - matchName: "api.example.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
YAML
STAGE10_SMOKE_TMP_DIR="$TMP_DIR" python3 - <<'PY'
import json
import os
from pathlib import Path

tmp_dir = Path(os.environ["STAGE10_SMOKE_TMP_DIR"])
allowlist_path = tmp_dir / "allowlist.json"
patch_path = tmp_dir / "exception-patches/stage10-smoke-egress.json"
allowlist = json.loads(allowlist_path.read_text())
patch = json.loads(patch_path.read_text())
collection = {key: patch["collection"][key] for key in ["name", "priority", "action", "rules"]}
allowlist["application_rule_collections"].append(collection)
allowlist_path.write_text(json.dumps(allowlist, indent=2) + "\n")

kustomization_path = tmp_dir / "overlays/demo/network/egress-exceptions/kustomization.yaml"
text = kustomization_path.read_text()
if "stage10-smoke-egress.yaml" not in text:
    if text.strip() == "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources: []":
        text = "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n  - stage10-smoke-egress.yaml\n"
    else:
        text = text.rstrip() + "\n  - stage10-smoke-egress.yaml\n"
    kustomization_path.write_text(text)
PY
EGRESS_ALLOWLIST="${TMP_DIR}/allowlist.json" \
EGRESS_PATCH_DIR="$EGRESS_PATCH_DIR" \
EGRESS_OVERLAYS_DIR="${TMP_DIR}/overlays" \
python3 "${ROOT}/scripts/policy/validate_egress_exception_patches.py"

if [ "${STAGE10_SMOKE_AZURE:-false}" = "true" ]; then
  for tool in az jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "ERROR: Missing required Azure CLI tool: $tool" >&2
      exit 1
    fi
  done

  required=(
    AZURE_SUBSCRIPTION_ID
    PLATFORM_RESOURCE_GROUP_NAME
    PLATFORM_AKS_CLUSTER_NAME
    PLATFORM_ACR_NAME
  )
  missing=()
  for name in "${required[@]}"; do
    if [ -z "${!name:-}" ]; then missing+=("$name"); fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: Missing Stage 10 Azure smoke variables: ${missing[*]}" >&2
    exit 2
  fi

  az account set --subscription "$AZURE_SUBSCRIPTION_ID"
  az group show --name "$PLATFORM_RESOURCE_GROUP_NAME" --query "{name:name,location:location}" -o table
  az aks show \
    --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
    --name "$PLATFORM_AKS_CLUSTER_NAME" \
    --query "{name:name,oidc:oidcIssuerProfile.enabled,workloadIdentity:securityProfile.workloadIdentity.enabled}" \
    -o table
  az acr show \
    --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
    --name "$PLATFORM_ACR_NAME" \
    --query "{name:name,anonymousPull:anonymousPullEnabled,adminUser:adminUserEnabled}" \
    -o table
  if [ -n "${STAGE10_SMOKE_ENTRA_GROUP_OBJECT_ID:-}" ]; then
    az ad group show --group "$STAGE10_SMOKE_ENTRA_GROUP_OBJECT_ID" --query "{displayName:displayName,id:id}" -o table
  fi
fi

echo "Stage 10 onboarding smoke test passed."
