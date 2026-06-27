#!/usr/bin/env python3
"""Validate golden-path template repository contracts."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

TEMPLATES = [
    "aks-microservice",
    "aca-service",
    "aks-workload-namespace",
]

EXPECTED_FILES = [
    "templates/_partials/catalog-info.yaml",
    "templates/_partials/devcontainer/devcontainer.json",
    "templates/_partials/devcontainer/Dockerfile",
    "templates/_partials/mkdocs.yml",
    "templates/_partials/renovate.json",
    "templates/_partials/on-call-annotations.yaml",
    "templates/_partials/chart/templates/_helpers.tpl",
    "templates/aks-microservice/template.yaml",
    "templates/aks-microservice/skeleton/.devcontainer/devcontainer.json",
    "templates/aks-microservice/skeleton/.tool-versions",
    "templates/aks-microservice/skeleton/.github/workflows/ci.yml",
    "templates/aks-microservice/skeleton/catalog-info.yaml",
    "templates/aks-microservice/skeleton/.github/CODEOWNERS",
    "templates/aks-microservice/skeleton/chart/Chart.yaml",
    "templates/aks-microservice/skeleton/chart/templates/deployment.yaml",
    "templates/aks-microservice/skeleton/chart/templates/hpa.yaml",
    "templates/aks-microservice/skeleton/chart/templates/pdb.yaml",
    "templates/aks-microservice/skeleton/chart/templates/servicemonitor.yaml",
    "templates/aks-microservice/skeleton/gitops/dev/helmrelease.yaml",
    "templates/aks-microservice/skeleton/gitops/dev/slo.yaml",
    "templates/aks-microservice/skeleton/slo.yaml",
    "templates/aca-service/template.yaml",
    "templates/aca-service/skeleton/.devcontainer/devcontainer.json",
    "templates/aca-service/skeleton/.tool-versions",
    "templates/aca-service/skeleton/.github/workflows/ci.yml",
    "templates/aca-service/skeleton/.github/CODEOWNERS",
    "templates/aca-service/skeleton/catalog-info.yaml",
    "templates/aca-service/skeleton/infra/aca.tf",
    "templates/aca-service/skeleton/infra/variables.tf",
    "templates/aca-service/skeleton/infra/versions.tf",
    "templates/aca-service/skeleton/observability/app-insights-kql/availability.kql",
    "templates/aca-service/skeleton/observability/app-insights-kql/failure-ratio.kql",
    "templates/aca-service/skeleton/observability/app-insights-kql/latency-p95.kql",
    "templates/aca-service/skeleton/slo.yaml",
    "templates/aks-workload-namespace/template.yaml",
    "templates/aks-workload-namespace/skeleton/catalog/${{ values.namespace }}-resource.yaml",
    "templates/aks-workload-namespace/skeleton/vending/requests/namespaces/${{ values.namespace }}.yaml",
    "docs/runbooks/golden-paths.md",
    "docs/adr/0044-template-versioning.md",
    "docs/adr/0053-aca-gitops-exception.md",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_file(path: str) -> None:
    if not (ROOT / path).is_file():
        fail(f"Required file missing: {path}")


def require_contains(path: str, needle: str) -> None:
    if needle not in read(path):
        fail(f"{path} must contain {needle!r}")


def require_not_contains(path: str, needle: str) -> None:
    if needle in read(path):
        fail(f"{path} must not contain {needle!r}")


def parse_yaml(path: str) -> None:
    subprocess.run(
        ["ruby", "-ryaml", "-e", f"YAML.load_file({str(ROOT / path)!r})"],
        check=True,
    )


def require_same_content(source: str, generated: str) -> None:
    if read(source) != read(generated):
        fail(f"{generated} must match shared partial {source}")


def require_order(path: str, first: str, second: str) -> None:
    text = read(path)
    first_index = text.find(first)
    second_index = text.find(second)
    if first_index == -1 or second_index == -1 or first_index >= second_index:
        fail(f"{path} must list {first!r} before {second!r}")


def validate_shared_partials() -> None:
    for skeleton in ["aks-microservice", "aca-service"]:
        for relative_path in [
            ".devcontainer/devcontainer.json",
            ".devcontainer/Dockerfile",
            "mkdocs.yml",
            "renovate.json",
        ]:
            partial_path = {
                ".devcontainer/devcontainer.json": "templates/_partials/devcontainer/devcontainer.json",
                ".devcontainer/Dockerfile": "templates/_partials/devcontainer/Dockerfile",
                "mkdocs.yml": "templates/_partials/mkdocs.yml",
                "renovate.json": "templates/_partials/renovate.json",
            }[relative_path]
            require_same_content(partial_path, f"templates/{skeleton}/skeleton/{relative_path}")

    require_same_content(
        "templates/_partials/chart/templates/_helpers.tpl",
        "templates/aks-microservice/skeleton/chart/templates/_helpers.tpl",
    )
    require_same_content(
        "templates/_partials/slo.yaml",
        "templates/aks-microservice/skeleton/slo.yaml",
    )
    require_same_content(
        "templates/_partials/slo.yaml",
        "templates/aks-microservice/skeleton/gitops/dev/slo.yaml",
    )


def validate_template_definitions() -> None:
    for template in TEMPLATES:
        path = f"templates/{template}/template.yaml"
        parse_yaml(path)
        for needle in [
            "apiVersion: scaffolder.backstage.io/v1beta3",
            "kind: Template",
            "deprecated: false",
            "scaffolder.platform.example.io/api-version: scaffolder.platform.example.io/v1",
            "golden-path",
            "goldenPathTemplate: \"true\"",
            "teamName:",
            "productName:",
            "costCenter:",
            "dataClassification:",
            "confidentiality:",
            "onCallRotationId:",
        ]:
            require_contains(path, needle)
        if template == "aks-workload-namespace":
            require_contains(path, "platform-admin-only")
            require_not_contains(path, "- team-scoped")
        else:
            require_contains(path, "team-scoped")

    for path in ["backstage/app/app-config.yaml", "backstage/deploy/templates/configmap.yaml"]:
        for template in TEMPLATES:
            require_contains(path, f"templates/{template}/template.yaml")


def validate_permission_policy() -> None:
    path = "backstage/app/packages/backend/src/plugins/platformPermissionPolicy.ts"
    for needle in [
        "values.teamScopedTemplate",
        "values.goldenPathTemplate",
        "values.platformRepoOwner",
        "values.platformRepoName",
        "values.goldenPathType",
        "aks-microservice",
        "aca-service",
        "publish:github:pull-request",
        "AKS microservice",
        "ACA service",
        "allowGoldenPathRequestFor",
        "targetPath",
        "branchName",
        "not: teamScopedTemplateActionCondition",
    ]:
        require_contains(path, needle)
    require_contains("Makefile", "-not -path './golden-path-requests/*'")


def validate_aks_microservice() -> None:
    inherited_secrets = "secrets:" + " inherit"
    for path, needles in {
        "templates/aks-microservice/template.yaml": [
            "componentTitle:",
            "pattern: \"^[A-Za-z0-9][A-Za-z0-9 ._-]",
            "pattern: \"^[a-z][a-z0-9-]{1,38}[a-z0-9]$\"",
            "language:",
            "targetPath: ${{ parameters.componentId }}",
            "namespace:",
            "maxLength: 58",
            "publicExposure:",
            "serviceAccountName:",
            "publish:github:pull-request",
            "platformRepoUrl:",
            "repoUrl: ${{ parameters.platformRepoUrl }}",
            "branchName: golden-path-aks-${{ parameters.teamName }}",
            "targetPath: golden-path-requests/aks/${{ parameters.teamName }}",
            "branch protection",
            "CODEOWNERS",
            "pe-security-reviewers",
            "app-team-${{ parameters.teamName }}",
        ],
        "templates/aks-microservice/skeleton/.github/workflows/ci.yml": [
            "pr-validate:",
            "Build container locally",
            "Install mise toolchain",
            "mise exec -- helm lint chart",
            "container-build-sign.yml@main",
            "helm-publish.yml@main",
            "gitops-push.yml@main",
            "techdocs-publish.yml@main",
            "image_digest_ref:",
            "acr_login_server:",
            "chart_digest_ref:",
            "kustomization_resource:",
            "PLATFORM_ACR_LOGIN_SERVER",
            "${{ '${{ needs.build.outputs.digest_ref }}' }}",
            "${{ '${{ needs.helm.outputs.digest_ref }}' }}",
            "if: ${{ \"${{ github.ref == 'refs/heads/main' && github.event_name == 'push' }}\" }}",
        ],
        "templates/aks-microservice/skeleton/.tool-versions": [
            "helm 3.16.3",
            "cosign 2.4.1",
        ],
        "templates/aks-microservice/skeleton/chart/templates/deployment.yaml": [
            "azure.workload.identity/use",
            "golden-path.podLabels",
            "runAsNonRoot: true",
            "readOnlyRootFilesystem: true",
            "OTEL_SERVICE_NAME",
        ],
        "templates/aks-microservice/skeleton/chart/templates/hpa.yaml": [
            "and .Values.autoscaling.enabled (not .Values.autoscaling.keda.enabled)",
        ],
        "templates/aks-microservice/skeleton/chart/templates/servicemonitor.yaml": [
            "kind: ServiceMonitor",
        ],
        "templates/aks-microservice/skeleton/slo.yaml": [
            "kind: PrometheusServiceLevel",
            'replace("-", "_")',
            "runbook_url:",
            "dashboard_url:",
        ],
        "templates/aks-microservice/skeleton/gitops/dev/helmrelease.yaml": [
            "kind: HelmRelease",
            'namespace: "${{ values.namespace }}"',
            'storageNamespace: "helm-${{ values.namespace }}"',
            'serviceAccountName: "helm-${{ values.serviceAccountName }}"',
            "sha256:REPLACE_WITH_SIGNED_DIGEST",
            "create: false",
        ],
        "templates/aks-microservice/skeleton/gitops/dev/ocirepository.yaml": [
            "kind: OCIRepository",
            'namespace: "${{ values.namespace }}"',
            "$(PLATFORM_ACR_LOGIN_SERVER)",
            "provider: azure",
            "sha256:REPLACE_WITH_SIGNED_CHART_DIGEST",
            "matchOIDCIdentity:",
            "${{ values.platformRepoOwner }}/${{ values.platformRepoName }}/\\\\.github/workflows/helm-publish\\\\.yml@refs/heads/main",
        ],
        "templates/aks-microservice/skeleton/catalog-info.yaml": [
            "backstage.io/techdocs-ref: dir:.",
            'title: "${{ values.componentTitle }}"',
            'description: "${{ values.description }}"',
        ],
        "templates/aks-microservice/skeleton/chart/Chart.yaml": [
            'description: "Helm chart for ${{ values.componentTitle }}"',
        ],
        "templates/aks-microservice/skeleton/.github/CODEOWNERS": [
            "* @${{ values.githubOwner }}/app-team-${{ values.teamName }}",
            "/.mise.toml @${{ values.githubOwner }}/pe-platform-admins",
            "/.tool-versions @${{ values.githubOwner }}/pe-platform-admins",
            "/mise.toml @${{ values.githubOwner }}/pe-platform-admins",
            "/.github/ @${{ values.githubOwner }}/pe-platform-admins",
            "/chart/ @${{ values.githubOwner }}/pe-platform-admins",
            "/gitops/ @${{ values.githubOwner }}/pe-platform-admins",
        ],
    }.items():
        for needle in needles:
            require_contains(path, needle)

    for tag in [
        "costCenter",
        "product",
        "dataClassification",
        "confidentiality",
        "managedBy",
    ]:
        require_contains("templates/aks-microservice/skeleton/chart/values.yaml", tag)
    require_contains("templates/aks-microservice/skeleton/chart/templates/_helpers.tpl", "platform.example.io/repo")
    for needle in ["app:", "team:", "costCenter:", "dataClassification:", "golden-path.podLabels"]:
        require_contains("templates/aks-microservice/skeleton/chart/templates/_helpers.tpl", needle)
    require_not_contains("templates/aks-microservice/skeleton/chart/templates/_helpers.tpl", "\nrepo:")
    require_contains("templates/aks-microservice/skeleton/chart/templates/serviceaccount.yaml", "{{- if .Values.serviceAccount.create }}")
    require_order(
        "templates/aks-microservice/skeleton/.github/CODEOWNERS",
        "* @${{ values.githubOwner }}/app-team-${{ values.teamName }}",
        "/.github/ @${{ values.githubOwner }}/pe-platform-admins",
    )
    for needle in ["COPY package*.json ./", "USER 1000", "USER 10001", "USER 64198"]:
        require_contains("templates/aks-microservice/skeleton/Dockerfile", needle)
    require_contains("templates/aks-microservice/skeleton/chart/templates/deployment.yaml", "if not .Values.autoscaling.enabled")
    require_not_contains("templates/aks-microservice/skeleton/chart/templates/deployment.yaml", "prometheus.io/scrape")
    for path in [
        "templates/aks-microservice/skeleton/src/node-ts/server.js",
        "templates/aks-microservice/skeleton/src/python/app.py",
        "templates/aks-microservice/skeleton/src/dotnet/Program.cs",
    ]:
        for needle in ["/metrics", "http_server_requests_total", "${{ values.componentId }}"]:
            require_contains(path, needle)
    require_contains("templates/aks-microservice/skeleton/src/dotnet/Program.cs", "ConcurrentDictionary")
    require_not_contains(
        "templates/aks-microservice/skeleton/.github/workflows/ci.yml",
        "promote-image.yml@main",
    )
    require_not_contains(
        "templates/aks-microservice/skeleton/.github/workflows/ci.yml",
        "image_ref: ${{ needs.build.outputs.digest_ref }}",
    )
    require_not_contains(
        "templates/aks-microservice/skeleton/.github/workflows/ci.yml",
        inherited_secrets,
    )
    require_not_contains(
        "templates/aks-microservice/skeleton/.github/workflows/ci.yml",
        "pr_body: Signed image digest `${{ needs.build.outputs.digest_ref }}`",
    )
    require_not_contains("platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml", "ciliumnetworkpolicies")
    require_not_contains("templates/aks-microservice/skeleton/chart/values.yaml", "networkPolicy:")
    if (ROOT / "templates/aks-microservice/skeleton/chart/templates/networkpolicy.yaml").exists():
        fail("AKS golden path tenant chart must not author NetworkPolicy directly")
    if (ROOT / "templates/aks-microservice/skeleton/chart/templates/cilium-egress-policy.yaml").exists():
        fail("AKS golden path must not let tenant charts author CiliumNetworkPolicy directly")


def validate_aca_service() -> None:
    for path, needles in {
        "templates/aca-service/template.yaml": [
            "maxLength: 21",
            "pattern: \"^[a-z0-9][a-z0-9-]{1,19}[a-z0-9]$\"",
            "scaleRule:",
            "targetPath: ${{ parameters.componentId }}",
            "publish:github:pull-request",
            "platformRepoUrl:",
            "repoUrl: ${{ parameters.platformRepoUrl }}",
            "branchName: golden-path-aca-${{ parameters.teamName }}",
            "targetPath: golden-path-requests/aca/${{ parameters.teamName }}",
            "branch protection",
            "CODEOWNERS",
            "protected environment variables",
            "pe-security-reviewers",
            "app-team-${{ parameters.teamName }}",
        ],
        "templates/aca-service/skeleton/.github/workflows/ci.yml": [
            "pr-validate:",
            "Build container locally",
            "Install mise toolchain",
            "mise exec -- terraform -chdir=infra init -backend=false",
            "container-build-sign.yml@main",
            "techdocs-publish.yml@main",
            "cosign verify",
            "az containerapp update",
            "Validate protected platform inputs",
            "Verify signed digest before plan",
            "PLATFORM_ACA_ENVIRONMENT_ID",
            "PLATFORM_RESOURCE_GROUP_NAME",
            "PLATFORM_ACR_ID",
            "PLATFORM_ACR_LOGIN_SERVER",
            "PLATFORM_ACR_NAME",
            "PLATFORM_ACA_QUEUE_NAME",
            "PLATFORM_ACA_QUEUE_STORAGE_ACCOUNT_NAME",
            "PLATFORM_ACA_QUEUE_STORAGE_ACCOUNT_ID",
            "appinsights-connection-string",
            "secretref:appinsights-connection-string",
            "terraform -chdir=infra validate",
            "TFSTATE_RESOURCE_GROUP",
            "TFSTATE_STORAGE_ACCOUNT",
            "TFSTATE_CONTAINER",
            "backend.hcl",
            "golden-paths/aca/${{ values.environment }}/${{ values.componentId }}.tfstate",
            "if: ${{ \"${{ github.ref == 'refs/heads/main' && github.event_name == 'push' }}\" }}",
            "${{ values.platformRepoOwner }}/${{ values.platformRepoName }}/.github/workflows/container-build-sign.yml@refs/heads/main",
        ],
        "templates/aca-service/skeleton/.tool-versions": [
            "terraform 1.9.8",
            "cosign 2.4.1",
        ],
        "templates/aca-service/skeleton/infra/aca.tf": [
            "resource \"azurerm_container_app\" \"this\"",
            "resource \"azurerm_role_assignment\" \"acr_pull\"",
            "resource \"azurerm_role_assignment\" \"queue_reader\"",
            "resource \"terraform_data\" \"input_guard\"",
            "container_app_environment_id = var.container_app_environment_id",
            "registry {",
            "identity = azurerm_user_assigned_identity.workload.id",
            "ignore_changes",
            "http_scale_rule",
            "custom_scale_rule",
            "identity_id      = azurerm_user_assigned_identity.workload.id",
            "Storage Queue Data Reader",
            "local.queue_resource_id",
        ],
        "templates/aca-service/skeleton/infra/variables.tf": [
            "component_id must be a DNS-safe slug no longer than 21 characters",
        ],
        "templates/aca-service/skeleton/infra/versions.tf": [
            'backend "azurerm" {}',
        ],
        "templates/aca-service/skeleton/slo.yaml": [
            "kind: ApplicationInsightsSLO",
            "source: log-analytics-containerapp-console",
            "observability/app-insights-kql/availability.kql",
        ],
        "templates/aca-service/skeleton/.github/CODEOWNERS": [
            "* @${{ values.githubOwner }}/app-team-${{ values.teamName }}",
            "/.mise.toml @${{ values.githubOwner }}/pe-platform-admins",
            "/.tool-versions @${{ values.githubOwner }}/pe-platform-admins",
            "/mise.toml @${{ values.githubOwner }}/pe-platform-admins",
            "/.github/ @${{ values.githubOwner }}/pe-platform-admins",
            "/infra/ @${{ values.githubOwner }}/pe-platform-admins",
        ],
        "templates/aca-service/skeleton/catalog-info.yaml": [
            "backstage.io/techdocs-ref: dir:.",
        ],
    }.items():
        for needle in needles:
            require_contains(path, needle)

    for needle in ["acaEnvironmentId:", "resourceGroupName:", "values.acaEnvironmentId", "values.resourceGroupName"]:
        require_not_contains("templates/aca-service/template.yaml", needle)
    require_not_contains("templates/aks-microservice/template.yaml", "repoVisibility: ${{ parameters.repoVisibility }}")
    require_not_contains("templates/aca-service/template.yaml", "repoVisibility: ${{ parameters.repoVisibility }}")
    require_not_contains("templates/aks-microservice/template.yaml", "action: publish:github\n")
    require_not_contains("templates/aca-service/template.yaml", "action: publish:github\n")
    for needle in ["queueName:", "queueStorageAccountName:", "queueStorageAccountId:"]:
        require_not_contains("templates/aca-service/template.yaml", needle)
    for needle in ["REPLACE_WITH_SUBSCRIPTION_ID", "REPLACE_WITH_SIGNED_DIGEST", "app_insights_connection_string"]:
        require_not_contains("templates/aca-service/skeleton/infra/${{ values.environment }}.tfvars", needle)
        require_not_contains("templates/aca-service/skeleton/infra/variables.tf", needle)
        require_not_contains("templates/aca-service/skeleton/infra/aca.tf", needle)
    for needle in ["queue_name", "queue_storage_account_name", "queue_storage_account_id"]:
        require_not_contains("templates/aca-service/skeleton/infra/${{ values.environment }}.tfvars", needle)
    require_order(
        "templates/aca-service/skeleton/.github/CODEOWNERS",
        "* @${{ values.githubOwner }}/app-team-${{ values.teamName }}",
        "/.github/ @${{ values.githubOwner }}/pe-platform-admins",
    )
    for needle in ["COPY package*.json ./", "USER 1000", "USER 10001", "USER 64198"]:
        require_contains("templates/aca-service/skeleton/Dockerfile", needle)
    for path in [
        "templates/aca-service/skeleton/src/node-ts/server.js",
        "templates/aca-service/skeleton/src/python/app.py",
        "templates/aca-service/skeleton/src/dotnet/Program.cs",
    ]:
        for needle in ["/metrics", "http_server_requests_total", "http_request", "duration_ms", "${{ values.componentId }}"]:
            require_contains(path, needle)
    require_contains("templates/aca-service/skeleton/src/dotnet/Program.cs", "ConcurrentDictionary")
    for path in [
        "templates/aca-service/skeleton/observability/app-insights-kql/availability.kql",
        "templates/aca-service/skeleton/observability/app-insights-kql/failure-ratio.kql",
        "templates/aca-service/skeleton/observability/app-insights-kql/latency-p95.kql",
    ]:
        for needle in ["ContainerAppConsoleLogs_CL", "traces", "http_request", "${{ values.componentId }}"]:
            require_contains(path, needle)
    require_not_contains("templates/aca-service/skeleton/.github/workflows/ci.yml", "TF_VAR_app_insights_connection_string")
    require_not_contains("templates/aca-service/skeleton/infra/aca.tf", "azurerm_container_app_environment")
    for tag in [
        "costCenter",
        "product",
        "dataClassification",
        "confidentiality",
        "managedBy",
        "repo",
    ]:
        require_contains("templates/aca-service/skeleton/infra/variables.tf", tag)
    for path in (ROOT / "templates/aca-service/skeleton").rglob("*"):
        if path.is_file() and path.suffix.lower() in {".bicep", ".bicepparam"}:
            fail("ACA golden path must not generate Bicep files")


def validate_namespace_template() -> None:
    for path, needles in {
        "templates/aks-workload-namespace/template.yaml": [
            "quotaTier:",
            "maxLength: 32",
            "maxLength: 22",
            "namespace:",
            "maxLength: 58",
            "maxLength: 57",
            "pattern: \"^[a-z]+[a-z0-9]+$\"",
            "- namespace",
            "branchName: vend-namespace-${{ parameters.namespace }}",
            "entraGroupObjectId:",
            "aksClusterId:",
            "acrId:",
            "publish:github:pull-request",
            "teamReviewers:",
            "pe-platform-admins",
            "pe-security-reviewers",
        ],
        "templates/aks-workload-namespace/skeleton/vending/requests/namespaces/${{ values.namespace }}.yaml": [
            "kind: NamespaceVendingRequest",
            '- "${{ values.region }}"',
            'name: "${{ values.namespace }}"',
            "resourceQuota:",
            "entraGroupObjectId:",
            "keyVaultSecretIds: []",
            "managedBy: terraform",
        ],
        "templates/aks-workload-namespace/skeleton/catalog/${{ values.namespace }}-resource.yaml": [
            "kind: Resource",
            'title: "${{ values.namespace }} AKS namespace"',
            "type: kubernetes-namespace",
            'owner: "group:default/pe-app-team-${{ values.teamName }}"',
        ],
    }.items():
        for needle in needles:
            require_contains(path, needle)


def validate_gitops_workflow() -> None:
    path = ".github/workflows/gitops-push.yml"
    for needle in [
        "image_digest_ref:",
        "acr_login_server:",
        "chart_digest_ref:",
        "kustomization_resource:",
        "sha256:REPLACE_WITH_SIGNED_DIGEST",
        "sha256:REPLACE_WITH_SIGNED_CHART_DIGEST",
        "$(PLATFORM_ACR_LOGIN_SERVER)",
        "text.split(placeholder).join(replacement)",
        "ACR login server placeholders remain",
        "Parent kustomization.yaml not found",
        "resources: block",
        "Image digest placeholders remain",
        "Chart digest placeholders remain",
        "^sha256:[0-9a-f]{64}$",
        "image_digest_ref must be a digest-pinned image reference",
    ]:
        require_contains(path, needle)
    parse_yaml(path)
    for needle in [
        "source.toolkit.fluxcd.io",
        "ocirepositories",
        "helm.toolkit.fluxcd.io",
        "helmreleases",
        "sloth.slok.dev",
        "prometheusservicelevels",
        "policy",
        "poddisruptionbudgets",
        "monitoring.coreos.com",
        "servicemonitors",
    ]:
        require_contains("platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml", needle)
    require_contains("platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml", 'resources: ["networkpolicies"]\n    verbs: ["get", "list", "watch"]')
    require_not_contains("platform-gitops/clusters/_base/flux-system/tenant-reconciler-clusterrole.yaml", "\"secrets\"")
    for needle in [
        "platform:tenant-helm-release-storage",
        "resources: [\"secrets\"]",
    ]:
        require_contains("platform-gitops/clusters/_base/flux-system/tenant-helm-storage-clusterrole.yaml", needle)
    for needle in [
        "helm_service_account_name",
        "helm_storage_namespace",
        "helm-serviceaccount.yaml",
        "helm-storage-namespace.yaml",
        "helm-storage-rolebinding.yaml",
        "platform:tenant-helm-release-storage",
        "helm-rolebinding.yaml",
        "rb-${var.namespace}-helm-reconciler",
        '"kubernetes.io/metadata.name" = "ingress-nginx"',
        '"kubernetes.io/metadata.name" = "observability"',
        '"kubernetes.io/metadata.name" = "kube-system"',
        'port     = 53',
        "egress_allowlist_ports",
    ]:
        require_contains("infrastructure/terraform/vending/aks-namespace/locals.tf", needle)
    for needle in [
        'variable "egress_allowlist_ports"',
        "port     = 443",
        "port     = 5432",
        "port     = 5671",
    ]:
        require_contains("infrastructure/terraform/vending/aks-namespace/variables.tf", needle)
    require_contains("infrastructure/terraform/vending/aks-namespace/locals.tf", 'helm_storage_namespace    = "helm-${var.namespace}"')
    require_contains("infrastructure/terraform/vending/aks-namespace/variables.tf", "no longer than 57 characters")


def validate_docs() -> None:
    for path, needles in {
        "docs/runbooks/golden-paths.md": [
            "aks-workload-namespace",
            "aks-microservice",
            "aca-service",
            "image and chart digest placeholders",
        ],
        "docs/adr/0044-template-versioning.md": [
            "scaffolder.platform.example.io/v1",
            "metadata.deprecated",
        ],
        "docs/adr/0053-aca-gitops-exception.md": [
            "az containerapp update",
            "Terraform ignores subsequent image drift",
        ],
        "docs/adr/README.md": [
            "0044 | Template versioning | Accepted",
            "0053 | ACA GitOps exception | Accepted",
        ],
        "docs/runbooks/README.md": [
            "golden-paths.md",
        ],
    }.items():
        for needle in needles:
            require_contains(path, needle)


def main() -> None:
    for path in EXPECTED_FILES:
        require_file(path)
    validate_template_definitions()
    validate_shared_partials()
    validate_permission_policy()
    validate_aks_microservice()
    validate_aca_service()
    validate_namespace_template()
    validate_gitops_workflow()
    validate_docs()
    print("Golden-path contracts validated.")


if __name__ == "__main__":
    main()
