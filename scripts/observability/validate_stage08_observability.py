#!/usr/bin/env python3
"""Validate Stage 08 observability, SRE, and FinOps repository contracts."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]


EXPECTED_FILES = [
    "platform-gitops/clusters/_base/addon-config/observability/otel-conventions-configmap.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/dashboards/platform-slos-dashboard.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/keda/keda-scale-to-zero-pattern.yaml",
    "platform-gitops/clusters/_base/controllers/platform/helmrepository-fairwinds-stable.yaml",
    "platform-gitops/clusters/_base/controllers/platform/vpa.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/vpa-rightsizing-reporter-configmap.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/vpa-rightsizing-reporter-serviceaccount.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/vpa-rightsizing-reporter-clusterrole.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/vpa-rightsizing-reporter-clusterrolebinding.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/vpa-rightsizing-reporter-cronjob.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/platform-key-vault-secretstore.yaml",
    "platform-gitops/clusters/_base/addon-config/observability/rightsizing/platform-rightsizing-github-externalsecret.yaml",
    "templates/_partials/slo.yaml",
    "templates/_partials/slo-rule-group.tf.tmpl",
    "templates/_partials/keda-scaledobject.yaml",
    "infrastructure/terraform/_modules/cost-allocator/main.tf",
    ".github/workflows/ttl-sweep.yml",
    "workflows/ttl-sweep.yml",
    "scripts/azure/validate_stage08_azure.sh",
    "docs/runbooks/platform-slos.md",
    "docs/runbooks/sre/platform-slo-burn.md",
    "docs/runbooks/sre/flux-reconciliation-latency.md",
    "docs/runbooks/sre/cluster-api-availability.md",
    "docs/runbooks/sre/cost-showback-failure.md",
    "docs/adr/0037-otel-conventions.md",
    "docs/adr/0038-slo-tooling.md",
    "docs/adr/0039-on-call-tooling.md",
    "docs/adr/0040-status-page-tooling.md",
]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_file(path: str) -> None:
    if not (ROOT / path).is_file():
        fail(f"Required Stage 08 file missing: {path}")


def require_contains(path: str, needle: str) -> None:
    if needle not in read(path):
        fail(f"{path} must contain {needle!r}")


def main() -> None:
    for path in EXPECTED_FILES:
        require_file(path)

    kustomization = read("platform-gitops/clusters/_base/addon-config/kustomization.yaml")
    for expected in [
        "observability/otel-conventions-configmap.yaml",
        "observability/dashboards/platform-slos-dashboard.yaml",
        "observability/keda/keda-scale-to-zero-pattern.yaml",
        "observability/rightsizing/vpa-rightsizing-reporter-configmap.yaml",
        "observability/rightsizing/vpa-rightsizing-reporter-serviceaccount.yaml",
        "observability/rightsizing/vpa-rightsizing-reporter-clusterrole.yaml",
        "observability/rightsizing/vpa-rightsizing-reporter-clusterrolebinding.yaml",
        "observability/rightsizing/vpa-rightsizing-reporter-cronjob.yaml",
    ]:
        if expected not in kustomization:
            fail(f"addon-config kustomization does not reference {expected}")

    for attr in ["service.name", "service.namespace", "team", "product", "deployment.environment", "version"]:
        require_contains("platform-gitops/clusters/_base/addon-config/observability/otel-conventions-configmap.yaml", attr)

    require_contains("platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml", "tail_sampling")
    require_contains("platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml", "replicaCount: 1")
    require_contains("platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml", "type: probabilistic")
    require_contains("platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml", "sampling_percentage: 10")
    require_contains("platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml", "sampling_percentage")
    require_contains("platform-gitops/clusters/overlays/demo/controllers/kustomization.yaml", "value: 100")
    if "platform/opentelemetry-collector-node.yaml" in read("platform-gitops/clusters/_base/controllers/kustomization.yaml"):
        fail("Node OpenTelemetry collector uses hostPath and hostPort; keep it out of the default PSA-baseline controller set")
    require_contains("infrastructure/terraform/platform/gitops.tf", "platform_profile")

    require_contains("platform-gitops/clusters/_base/controllers/platform/vpa.yaml", "chart: vpa")
    require_contains("templates/_partials/slo.yaml", "runbook_url")
    require_contains("templates/_partials/slo-rule-group.tf.tmpl", "azurerm_monitor_alert_prometheus_rule_group")
    require_contains("templates/_partials/keda-scaledobject.yaml", "minReplicaCount: 0")
    require_contains("templates/_partials/keda-scaledobject.yaml", "https://prometheus-query.platform.internal")
    require_contains("platform-gitops/clusters/_base/addon-config/observability/rightsizing/platform-rightsizing-github-externalsecret.yaml", "platform-rightsizing-github-token")

    require_contains("infrastructure/terraform/platform/aks.tf", "nodeProvisioningProfile")
    require_contains("infrastructure/terraform/platform/monitoring.tf", "azurerm_monitor_action_group")
    require_contains("infrastructure/terraform/platform/monitoring.tf", "azurerm_monitor_alert_prometheus_rule_group")
    require_contains("infrastructure/terraform/platform/monitoring.tf", "itsm_receiver")
    require_contains("infrastructure/terraform/platform/finops.tf", "module \"cost_allocator\"")
    require_contains("infrastructure/terraform/platform/variables.tf", "enable_cost_allocator")
    require_contains("infrastructure/terraform/platform/main.tf", "cost_allocator_function_package_path")
    require_contains("infrastructure/terraform/platform/finops.tf", "private_endpoint_subnet_id")
    require_contains("infrastructure/terraform/_modules/cost-allocator/main.tf", "azurerm_linux_function_app")
    require_contains("infrastructure/terraform/_modules/cost-allocator/main.tf", "azurerm_private_endpoint")
    require_contains("infrastructure/terraform/_modules/cost-allocator/main.tf", "subresource_names              = [\"sites\"]")
    require_contains("infrastructure/terraform/_modules/cost-allocator/main.tf", "storage_uses_managed_identity")
    require_contains("infrastructure/terraform/_modules/cost-allocator/main.tf", "Storage Blob Data Reader")
    require_contains(".github/workflows/ttl-sweep.yml", "az resource list")
    require_contains(".github/workflows/ttl-sweep.yml", "expiresOn")
    require_contains(".github/workflows/ttl-sweep.yml", "gh pr create")
    require_contains("scripts/azure/validate_stage08_azure.sh", "az aks show")
    require_contains("scripts/azure/validate_stage08_azure.sh", "az monitor action-group show")
    require_contains("scripts/azure/validate_stage08_azure.sh", "az costmanagement export show")

    print("Stage 08 observability, SRE, and FinOps contracts validated.")


if __name__ == "__main__":
    main()
