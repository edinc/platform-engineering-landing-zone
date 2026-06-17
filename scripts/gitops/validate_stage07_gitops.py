#!/usr/bin/env python3
"""Validate Stage 07 GitOps and in-cluster platform contracts."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]

EXPECTED_POLICIES = {
    "disallow-host-namespaces.yaml",
    "disallow-host-path-volumes.yaml",
    "disallow-latest-image-tag.yaml",
    "disallow-privileged-containers.yaml",
    "generate-default-network-policy.yaml",
    "require-default-network-policy.yaml",
    "require-pod-security-restricted.yaml",
    "require-read-only-root-filesystem.yaml",
    "require-resource-requests-limits.yaml",
    "require-run-as-non-root.yaml",
    "require-standard-labels.yaml",
    "require-tenant-gitops-guardrails.yaml",
    "restrict-cert-manager-issuers.yaml",
    "restrict-external-dns-hostnames.yaml",
    "restrict-tenant-reconciler-serviceaccounts.yaml",
    "verify-cosign-signatures.yaml",
}

EXPECTED_ADDONS = {
    "cert-manager": "platform-gitops/clusters/_base/controllers/platform/cert-manager.yaml",
    "external-dns": "platform-gitops/clusters/_base/controllers/platform/external-dns.yaml",
    "secrets-store-csi-driver": "platform-gitops/clusters/_base/controllers/platform/secrets-store-csi-driver.yaml",
    "external-secrets": "platform-gitops/clusters/_base/controllers/platform/external-secrets.yaml",
    "kyverno": "platform-gitops/clusters/_base/controllers/platform/kyverno.yaml",
    "azure-service-operator": "platform-gitops/clusters/_base/controllers/platform/aso.yaml",
    "keda": "platform-gitops/clusters/_base/controllers/platform/keda.yaml",
    "ingress-nginx": "platform-gitops/clusters/_base/controllers/platform/ingress-nginx.yaml",
    "opentelemetry-collector": "platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml",
}


def read(path: str) -> str:
    return (ROOT / path).read_text()


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_contains(path: str, needle: str) -> None:
    if needle not in read(path):
        fail(f"{path} must contain {needle!r}")


def validate_policies() -> None:
    policy_dir = ROOT / "policies/kyverno"
    policy_files = {path.name for path in policy_dir.glob("*.yaml")}
    missing = EXPECTED_POLICIES - policy_files
    if missing:
        fail(f"Missing Kyverno policies: {', '.join(sorted(missing))}")

    cluster_policy_count = 0
    for path in policy_dir.glob("*.yaml"):
        text = path.read_text()
        if "kind: ClusterPolicy" in text:
            cluster_policy_count += 1
    if cluster_policy_count < 10:
        fail(f"Expected at least 10 ClusterPolicy files, found {cluster_policy_count}")

    base = read("platform-gitops/clusters/_base/addon-config/kustomization.yaml")
    for policy in sorted(EXPECTED_POLICIES):
        if f"policies/kyverno/{policy}" not in base:
            fail(f"Addon config kustomization does not reference {policy}")
        mirrored = ROOT / "platform-gitops/clusters/_base/addon-config/policies/kyverno" / policy
        source = policy_dir / policy
        if not mirrored.is_file():
            fail(f"Mirrored GitOps policy is missing: {mirrored.relative_to(ROOT)}")
        if mirrored.read_text() != source.read_text():
            fail(f"Mirrored GitOps policy differs from source policy: {policy}")


def validate_gitops_seed() -> None:
    required_files = [
        "platform-gitops/clusters/_base/kustomization.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-cluster-state-source.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-reconciler-serviceaccount.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-reconciler-clusterrolebinding.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml",
        "platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml",
        "platform-gitops/clusters/_base/controllers/kustomization.yaml",
        "platform-gitops/clusters/_base/addon-config/kustomization.yaml",
        "platform-gitops/clusters/overlays/demo/tenants/kustomization.yaml",
        "platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml",
        "platform-gitops/clusters/overlays/demo/addon-config/kustomization.yaml",
        "platform-gitops/clusters/overlays/nonprod/tenants/kustomization.yaml",
        "platform-gitops/clusters/overlays/nonprod/controllers/kustomization.yaml",
        "platform-gitops/clusters/overlays/nonprod/addon-config/kustomization.yaml",
        "platform-gitops/clusters/overlays/prod/tenants/kustomization.yaml",
        "platform-gitops/clusters/overlays/prod/controllers/kustomization.yaml",
        "platform-gitops/clusters/overlays/prod/addon-config/kustomization.yaml",
    ]
    for path in required_files:
        if not (ROOT / path).is_file():
            fail(f"Required GitOps seed file is missing: {path}")

    for overlay in ("demo", "nonprod", "prod"):
        path = f"platform-gitops/clusters/overlays/{overlay}/kustomization.yaml"
        require_contains(path, "../../_base")
        require_contains(path, "tenants")
        require_contains(f"platform-gitops/clusters/overlays/{overlay}/controllers/kustomization.yaml", "../../../_base/controllers")
        require_contains(f"platform-gitops/clusters/overlays/{overlay}/addon-config/kustomization.yaml", "../../../_base/addon-config")

    tenant_role = read("platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml")
    if 'resources: ["*"]' in tenant_role or "resources:\n      - \"*\"" in tenant_role:
        fail("Tenant Flux reconciler must not grant wildcard ASO resource access")
    if "vaultssecrets" in tenant_role:
        fail("Tenant Flux reconciler must not grant ASO Key Vault secret write access")
    for api_group in ("servicebus.azure.com", "keyvault.azure.com", "dbforpostgresql.azure.com", "storage.azure.com"):
        if api_group in tenant_role:
            fail(f"Tenant roles must not grant direct ASO API group access: {api_group}")

    for addon, path in EXPECTED_ADDONS.items():
        require_contains(path, addon)

    for path in (ROOT / "platform-gitops/clusters/_base/controllers/platform").glob("*.yaml"):
        text = path.read_text()
        for match in re.finditer(r'^\s+version:\s+"([^"]+)"', text, re.MULTILINE):
            if "x" in match.group(1).lower():
                fail(f"{path.relative_to(ROOT)} must pin exact Helm chart versions")


def validate_terraform_and_workflows() -> None:
    require_contains("infrastructure/terraform/platform/gitops.tf", "azurerm_kubernetes_cluster_extension")
    require_contains("infrastructure/terraform/platform/gitops.tf", "azurerm_kubernetes_flux_configuration")
    require_contains("infrastructure/terraform/platform/gitops.tf", '"multiTenancy.enforce"')
    require_contains("infrastructure/terraform/platform/gitops.tf", "post_build")
    require_contains("infrastructure/terraform/platform/gitops.tf", "external_secrets_client_id")
    require_contains("infrastructure/terraform/platform/gitops.tf", "cluster_state_root_path")
    require_contains("infrastructure/terraform/vending/aks-namespace/main.tf", "Azure Kubernetes Service RBAC Reader")
    require_contains("infrastructure/terraform/cluster-state-repo/locals.tf", "legacy_seed_files")
    require_contains("infrastructure/terraform/cluster-state-repo/variables.tf", "stage07_seed_files_enabled")
    require_contains("infrastructure/terraform/platform/variables.tf", "https://|ssh://|git@")
    if "http://" in read("infrastructure/terraform/platform/variables.tf"):
        fail("platform variables must not allow insecure http:// GitOps repository URLs")
    require_contains("infrastructure/terraform/platform/aks.tf", "azure_policy_enabled              = false")
    require_contains("infrastructure/terraform/cluster-state-repo/locals.tf", "platform-gitops")
    require_contains("infrastructure/terraform/cluster-state-repo/locals.tf", "policies/kyverno")
    require_contains("infrastructure/terraform/vending/aks-namespace/locals.tf", "serviceAccountName")
    require_contains("infrastructure/terraform/vending/aks-namespace/locals.tf", "/workloads")
    require_contains("infrastructure/terraform/vending/aks-namespace/locals.tf", "name     = \"view\"")
    require_contains("infrastructure/terraform/vending/aks-namespace/main.tf", "workload_kustomization")
    require_contains("infrastructure/terraform/vending/aks-namespace/outputs.tf", "clusters/overlays/${var.environment}/tenants")
    require_contains(".github/workflows/vend-namespace.yml", "tenant_index=\"clusters/overlays/${environment}/tenants/kustomization.yaml\"")
    require_contains(".github/workflows/vend-namespace.yml", "tenant_bootstrap=")
    require_contains(".github/workflows/vend-namespace.yml", "scripts/gitops/update_tenant_index.py")
    require_contains("policies/kyverno/verify-cosign-signatures.yaml", "subjectRegExp: ^https://github\\.com/edinc/platform-engineering-landing-zone/\\.github/workflows/container-build-sign\\.yml@refs/heads/main$")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "postBuild")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "postBuild")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "serviceAccountName: platform-reconciler")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "serviceAccountName: platform-reconciler")


def main() -> None:
    validate_policies()
    validate_gitops_seed()
    validate_terraform_and_workflows()
    print("Stage 07 GitOps contracts validated.")


if __name__ == "__main__":
    main()
