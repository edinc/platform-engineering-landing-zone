#!/usr/bin/env python3
"""Validate GitOps platform contracts."""

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


def require_not_contains(path: str, needle: str) -> None:
    if needle in read(path):
        fail(f"{path} must not contain {needle!r}")


def require_regex(path: str, pattern: str) -> None:
    if not re.search(pattern, read(path), re.MULTILINE):
        fail(f"{path} must match {pattern!r}")


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
        "platform-gitops/clusters/_base/flux-system/platform-reconciler-serviceaccount.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-reconciler-clusterrolebinding.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml",
        "platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml",
        "platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml",
        "platform-gitops/clusters/_base/controllers/kustomization.yaml",
        "platform-gitops/clusters/_base/controllers/platform/external-dns-azure-config.yaml",
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
    require_contains("infrastructure/terraform/platform/variables.tf", 'variable "recreate_flux_extension_epoch"')
    require_contains("infrastructure/terraform/platform/gitops.tf", 'resource "terraform_data" "flux_extension_recreate_epoch"')
    require_contains("infrastructure/terraform/platform/gitops.tf", "replace_triggered_by")
    require_contains("infrastructure/terraform/platform/gitops.tf", "terraform_data.flux_extension_recreate_epoch")
    require_contains("infrastructure/terraform/platform/gitops.tf", '"multiTenancy.enforce"')
    require_contains("infrastructure/terraform/platform/gitops.tf", '"workloadIdentity.enable"')
    require_contains("infrastructure/terraform/platform/gitops.tf", "flux_source_workload_identity_client_id")
    for stale_setting in [
        "source-controller.featureGates",
        "sourceController.featureGates",
        "ObjectLevelWorkloadIdentity",
    ]:
        require_not_contains("infrastructure/terraform/platform/gitops.tf", stale_setting)
    require_contains("infrastructure/terraform/platform/gitops.tf", "post_build")
    require_contains("infrastructure/terraform/platform/gitops.tf", "ssh_private_key_base64")
    require_contains("infrastructure/terraform/platform/gitops.tf", "ssh_known_hosts_base64")
    require_contains("infrastructure/terraform/platform/gitops.tf", "external_secrets_client_id")
    require_contains("infrastructure/terraform/platform/gitops.tf", "cluster_state_root_path")
    require_not_contains("infrastructure/terraform/platform/gitops.tf", "backstage_public_ingress_allowed_cidr")
    require_not_contains("infrastructure/terraform/platform/variables.tf", "backstage_public_ingress_allowed_cidr")
    require_contains("infrastructure/terraform/platform/workload-identities.tf", "azurerm_user_assigned_identity")
    require_contains("infrastructure/terraform/platform/workload-identities.tf", "azurerm_federated_identity_credential")
    require_contains("infrastructure/terraform/platform/workload-identities.tf", "system:serviceaccount:")
    require_contains("infrastructure/terraform/platform/workload-identities.tf", "azurerm_role_definition")
    require_contains("infrastructure/terraform/platform/workload-identities.tf", "Platform ASO Operator")
    require_contains("infrastructure/terraform/platform/gitops.tf", "azurerm_federated_identity_credential.platform_workload")
    for path, service_account_name in {
        "platform-gitops/clusters/_base/controllers/platform/cert-manager.yaml": "name: cert-manager",
        "platform-gitops/clusters/_base/controllers/platform/external-dns.yaml": "name: external-dns",
        "platform-gitops/clusters/_base/controllers/platform/external-secrets.yaml": "name: external-secrets",
        "platform-gitops/clusters/_base/controllers/platform/aso.yaml": "name: azure-service-operator",
    }.items():
        require_contains(path, service_account_name)
        require_contains(path, "azure.workload.identity/tenant-id: ${platform_tenant_id}")
    for path in [
        "platform-gitops/clusters/_base/addon-config/backstage/serviceaccount.yaml",
        "platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/serviceaccount.yaml",
    ]:
        require_contains(path, "azure.workload.identity/tenant-id: ${platform_tenant_id}")
    require_contains("platform-gitops/clusters/_base/controllers/kustomization.yaml", "platform/external-dns-azure-config.yaml")
    require_contains("platform-gitops/clusters/_base/controllers/platform/external-dns.yaml", "external-dns-azure-config")
    require_contains("platform-gitops/clusters/_base/controllers/platform/external-dns-azure-config.yaml", '"useWorkloadIdentityExtension": true')
    require_contains("platform-gitops/clusters/_base/controllers/platform/namespace-azureserviceoperator-system.yaml", "platform.example.io/pod-security-exception: aso-chart-pre-upgrade-hook")
    require_contains("platform-gitops/clusters/_base/controllers/platform/namespace-azureserviceoperator-system.yaml", "pod-security.kubernetes.io/enforce: baseline")
    require_contains("policies/kyverno/require-pod-security-restricted.yaml", "azureserviceoperator-system")
    controllers_kustomization = read("platform-gitops/clusters/_base/controllers/kustomization.yaml")
    if "platform/secrets-store-csi-driver.yaml" in controllers_kustomization:
        fail("AKS key_vault_secrets_provider installs the CSI driver; do not deploy the duplicate Helm driver chart")
    if "platform/csi-secrets-store-provider-azure.yaml" in controllers_kustomization:
        fail("AKS key_vault_secrets_provider installs the Azure provider; do not deploy the duplicate Helm provider chart")
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
    require_contains("policies/kyverno/verify-cosign-signatures.yaml", "subjectRegExp: ^https://github\\.com/${github_owner}/${platform_repository_name}/\\.github/workflows/container-build-sign\\.yml@refs/heads/main$")
    require_contains("policies/kyverno/require-tenant-gitops-guardrails.yaml", "require-platform-helm-oci-url")
    require_contains("policies/kyverno/require-tenant-gitops-guardrails.yaml", "oci://${platform_acr_login_server}/helm/*")
    require_contains("policies/kyverno/require-tenant-gitops-guardrails.yaml", "request.object.spec.serviceAccountName")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "postBuild")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "postBuild")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "github_owner: ${github_owner}")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "platform_acr_login_server: ${platform_acr_login_server}")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "platform_repository_name: ${platform_repository_name}")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "aks_kubelet_client_id: ${aks_kubelet_client_id}")
    for expected in [
        'backstage_public_ingress_controller_replicas: "${backstage_public_ingress_controller_replicas}"',
        'backstage_public_ingress_enabled: "${backstage_public_ingress_enabled}"',
        'backstage_public_ingress_host: "${backstage_public_ingress_host}"',
        'backstage_public_ingress_public_ip_name: "${backstage_public_ingress_public_ip_name}"',
        'backstage_public_ingress_resource_group: "${backstage_public_ingress_resource_group}"',
    ]:
        require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", expected)
        require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", expected)
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", 'clusterconfig.azure.com/use-managed-source: "true"')
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", 'clusterconfig.azure.com/use-managed-source: "true"')
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "timeout: 20m")
    require_contains("platform-gitops/clusters/_base/controllers/platform/kyverno.yaml", "timeout: 15m")
    require_contains("platform-gitops/clusters/_base/controllers/platform/kyverno.yaml", "retries: 3")
    require_regex("platform-gitops/clusters/_base/controllers/platform/kyverno.yaml", r"policyReportsCleanup:\n\s+enabled: false")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-controllers-kustomization.yaml", "serviceAccountName: platform-reconciler")
    require_contains("platform-gitops/clusters/_base/flux-system/platform-config-kustomization.yaml", "serviceAccountName: platform-reconciler")
    require_contains("platform-gitops/clusters/overlays/demo/controllers/namespace-ingress-nginx-public.yaml", "pod-security.kubernetes.io/enforce: restricted")
    require_not_contains("platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml", "  - ingress-nginx-public.yaml")
    require_not_contains("platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml", "public-backstage-kustomization.yaml")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/kustomization.yaml", "ingress-nginx-public.yaml")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/kustomization.yaml", "public-backstage-kustomization.yaml")
    require_contains("platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml", "ingress-nginx-public-ingressclass-rbac.yaml")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/public-backstage-kustomization.yaml", "name: platform-demo")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/public-backstage-kustomization.yaml", "wait: false")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/public-backstage-kustomization.yaml", "public-backstage")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/public-backstage-kustomization.yaml", "backstage_public_ingress_host")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "default-ssl-certificate: ingress-nginx-public/backstage-public-tls")
    require_not_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "healthCheckNodePort")
    require_not_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "nodePorts")
    require_contains("platform-gitops/clusters/overlays/demo/controllers/ingress-nginx-public-ingressclass-rbac.yaml", "ingressclasses")
    require_contains("policies/kyverno/restrict-cert-manager-issuers.yaml", "ingress-nginx-public")
    require_contains("policies/kyverno/restrict-cert-manager-issuers.yaml", "letsencrypt-http01")
    require_contains("policies/kyverno/restrict-external-dns-hostnames.yaml", "ingress-nginx-public")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "replicaCount: ${backstage_public_ingress_controller_replicas}")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "scope: true")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "enabled: ${backstage_public_ingress_enabled}")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "backstage-public")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "service.beta.kubernetes.io/azure-pip-name")
    require_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "externalTrafficPolicy: Local")
    require_not_contains("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", "loadBalancerSourceRanges")
    require_not_contains("platform-gitops/clusters/overlays/demo/public-backstage/public-ingress.yaml", "nginx.ingress.kubernetes.io/whitelist-source-range")
    require_regex("infrastructure/terraform/platform/backstage-public-ingress.tf", r'name\s+=\s+"allow-backstage-public-lb"')
    require_regex("infrastructure/terraform/platform/backstage-public-ingress.tf", r'source_address_prefix\s+=\s+"Internet"')
    require_regex("infrastructure/terraform/platform/backstage-public-ingress.tf", r'destination_port_ranges\s+=\s+\["80", "443"\]')
    require_contains("infrastructure/terraform/platform/backstage-public-ingress.tf", "ip_tags")
    require_contains("infrastructure/terraform/platform/outputs.tf", "backstage_microsoft_auth_redirect_uri")
    require_regex("platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml", r"admissionWebhooks:\n\s+enabled: false")
    require_contains("policies/kyverno/verify-cosign-signatures.yaml", "ingress-nginx-public")
    require_contains("platform-gitops/clusters/_base/addon-config/policies/kyverno/verify-cosign-signatures.yaml", "ingress-nginx-public")


def main() -> None:
    validate_policies()
    validate_gitops_seed()
    validate_terraform_and_workflows()
    print("GitOps contracts validated.")


if __name__ == "__main__":
    main()
