#!/usr/bin/env python3
"""Validate Stage 09 Backstage MVP repository contracts."""

from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]

EXPECTED_FILES = [
    "backstage/app/package.json",
    "backstage/app/yarn.lock",
    "backstage/app/app-config.yaml",
    "backstage/app/app-config.production.yaml",
    "backstage/app/catalog-info.yaml",
    "backstage/app/Dockerfile",
    "backstage/catalog-reconciler/Dockerfile",
    "backstage/app/scripts/start-backstage.mjs",
    "backstage/app/packages/app/src/App.tsx",
    "backstage/app/packages/app/src/apis/PlatformCostInsightsClient.ts",
    "backstage/app/packages/backend/src/index.ts",
    "backstage/app/packages/backend/src/plugins/platformCostShowback.ts",
    "backstage/app/packages/backend/src/plugins/platformPermissionPolicy.ts",
    "backstage/app/scripts/validate-backstage-app.mjs",
    "backstage/deploy/Chart.yaml",
    "backstage/deploy/values.yaml",
    "backstage/deploy/templates/deployment.yaml",
    "backstage/deploy/templates/ingress.yaml",
    "backstage/deploy/templates/networkpolicy.yaml",
    "backstage/catalog-reconciler/Dockerfile",
    "backstage/catalog-reconciler/reconciler.py",
    "backstage/plugins/cost-insights-azure/package.json",
    "backstage/plugins/cost-insights-azure/src/adapter.ts",
    "platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/externalsecret.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/networkpolicy.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/ocirepository.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/rbac-groups-configmap.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/secretproviderclass.yaml",
    "platform-gitops/clusters/_base/addon-config/backstage/runtime-externalsecret.yaml",
    "infrastructure/terraform/platform/techdocs.tf",
    "policies/backstage/permissions.ts",
    "docs/runbooks/backstage-ops.md",
    "docs/adr/0020-build-vs-buy.md",
    "docs/adr/0041-backstage-rbac.md",
    "docs/adr/0042-techdocs-storage.md",
    "docs/adr/0052-backstage-postgres-auth.md",
    "scripts/azure/validate_stage09_azure.sh",
]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_file(path: str) -> None:
    if not (ROOT / path).is_file():
        fail(f"Required Stage 09 file missing: {path}")


def require_contains(path: str, needle: str) -> None:
    if needle not in read(path):
        fail(f"{path} must contain {needle!r}")


def render_kustomize(path: str) -> str:
    try:
        result = subprocess.run(
            ["kubectl", "kustomize", path],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        fail("kubectl is required to render Backstage Kustomize overlays")
    if result.returncode != 0:
        fail(f"kubectl kustomize {path} failed:\n{result.stderr}")
    return result.stdout


def validate_backstage_config() -> None:
    app_config = read("backstage/app/app-config.yaml")
    production_config = read("backstage/app/app-config.production.yaml")
    package_json = read("backstage/app/package.json")
    backend_index = read("backstage/app/packages/backend/src/index.ts")

    for needle in [
        "microsoft:",
        "microsoftGraphOrg:",
        "githubDiscovery:",
        "azureBlobStorage:",
        "@backstage/plugin-kubernetes",
        "@backstage-community/plugin-flux",
        "@backstage/plugin-github-actions",
        "@backstage-community/plugin-cost-insights",
        "permission:",
        "externalAccess:",
    ]:
        if needle not in app_config and needle not in production_config:
            fail(f"Backstage configuration must include {needle!r}")

    if "kubeconfig" in app_config.lower() or "kubeconfig" in production_config.lower():
        fail("Backstage Kubernetes plugin configuration must not store kubeconfig data")
    if "GRAFANA_TOKEN" in app_config or "/grafana/api" in app_config:
        fail("Backstage config must not expose Grafana through a static bearer-token proxy")
    rules_match = re.search(r"^  rules:\s*\n\s*-\s*allow:\s*\[([^\]]+)\]", app_config, flags=re.MULTILINE)
    if not rules_match:
        fail("Backstage catalog rules allow-list is missing")
    rules_text = rules_match.group(1)
    for disallowed_kind in ["Location", "User", "Group"]:
        if disallowed_kind in rules_text:
            fail(f"Backstage catalog rules must not allow repo-imported {disallowed_kind} entities")
    if "githubOrgDiscovery" in app_config:
        fail("GitHub org discovery must not import identity entities; use Microsoft Graph for User/Group")
    require_contains("backstage/app/app-config.yaml", "- allow: [User, Group]")
    require_contains("backstage/deploy/templates/configmap.yaml", "- allow: [User, Group]")
    require_contains("backstage/app/app-config.yaml", "templates/onboard-team/template.yaml")
    require_contains("backstage/app/app-config.yaml", "templates/request-egress-exception/template.yaml")
    require_contains("backstage/deploy/templates/configmap.yaml", "templates/onboard-team/template.yaml")
    require_contains("backstage/deploy/templates/configmap.yaml", "templates/request-egress-exception/template.yaml")
    require_contains("backstage/app/app-config.yaml", "credentials:\n        accountName:")
    require_contains("backstage/deploy/templates/configmap.yaml", "credentials:\n            accountName:")
    if "runtime-health-server" in package_json or (ROOT / "backstage/app/src/runtime-health-server.mjs").exists():
        fail("Backstage app must not use the Stage 09 placeholder health server")
    if "packages/*/src" in read("backstage/app/.dockerignore"):
        fail("Backstage Docker build needs package source files in the Docker context")
    require_contains("backstage/app/Dockerfile", "node .yarn/releases/yarn-4.4.1.cjs install --immutable")
    require_contains("backstage/app/Dockerfile", "tar xzf packages/backend/dist/skeleton.tar.gz")
    require_contains("backstage/app/Dockerfile", "tar xzf packages/backend/dist/bundle.tar.gz")
    require_contains("backstage/app/Dockerfile", '"--config", "app-config.yaml"')
    require_contains("backstage/app/packages/backend/package.json", "-f ../../Dockerfile")
    if (ROOT / "backstage/app/packages/backend/Dockerfile").exists():
        fail("Backstage root Dockerfile must be the single backend image contract")
    require_contains("backstage/app/app-config.production.yaml", "password: ${POSTGRES_PASSWORD}")
    require_contains("backstage/app/app-config.production.yaml", "user: ${POSTGRES_USER}")
    for needle in [
        "@backstage/create-app",
        "@backstage/plugin-auth-backend-module-microsoft-provider",
        "@backstage/plugin-catalog-backend-module-github",
        "@backstage/plugin-catalog-backend-module-msgraph",
        "platformPermissionPolicy",
    ]:
        if needle not in package_json and needle not in backend_index and needle not in read("backstage/app/README.md"):
            fail(f"Backstage scaffold/backend must include {needle!r}")
    app_frontend = read("backstage/app/packages/app/src/App.tsx")
    for needle in [
        "@backstage/plugin-kubernetes/alpha",
        "@backstage/plugin-github-actions",
        "@backstage-community/plugin-flux",
        "convertLegacyPlugin",
        "@backstage/plugin-techdocs/alpha",
        "@backstage/plugin-scaffolder/alpha",
        "@backstage-community/plugin-cost-insights/alpha",
        "Microsoft Entra ID",
        "microsoftAuthApiRef",
    ]:
        if needle not in app_frontend:
            fail(f"Backstage frontend must include {needle!r}")

    catalog = read("backstage/app/catalog-info.yaml")
    entity_count = len(re.findall(r"^kind:\s+", catalog, flags=re.MULTILINE))
    if entity_count < 8:
        fail(f"Expected at least 8 Backstage catalog entities, found {entity_count}")
    for needle in ["lifecycle: production", "owner: group:default/pe-platform-admins", "backstage.io/source-location", "backstage.io/kubernetes-id"]:
        require_contains("backstage/app/catalog-info.yaml", needle)


def validate_permissions() -> None:
    policy = read("backstage/app/packages/backend/src/plugins/platformPermissionPolicy.ts")
    for needle in [
        "platformAdminsGroupRef",
        "platformOperatorsGroupRef",
        "applicationTeamGroupRefs",
        "ownershipEntityRefs",
        "if (!user)",
        "catalog.entity.delete",
        "catalog.entity.read",
        "createCatalogConditionalDecision",
        "AuthorizeResult.DENY",
    ]:
        if needle not in policy:
            fail(f"Backstage permission policy must include {needle!r}")
    if "pe-platform-admins" in policy or "pe-app-team-" in policy:
        fail("Backstage permission policy must read group names from config instead of hard-coding names")
    require_contains("policies/backstage/permissions.ts", "platformPermissionPolicy")
    require_contains("backstage/app/packages/backend/src/index.ts", "platformPermissionPolicy")
    if "isApplicationTeam && permissionName === 'kubernetes.resources.read'" in policy:
        fail("Application-team Kubernetes access must remain disabled until Stage 10 namespace RBAC")
    require_contains("backstage/deploy/templates/configmap.yaml", "BACKSTAGE_MICROSOFT_GRAPH_GROUP_FILTER")
    require_contains("backstage/deploy/templates/deployment.yaml", "BACKSTAGE_APPLICATION_TEAM_GROUP_REFS")
    require_contains("backstage/deploy/values.yaml", "standardLabels:")
    require_contains("backstage/deploy/values.yaml", "app: backstage")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "standardLabels:")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "enabled: false")
    for label in ["app: backstage", "team: platform-engineering", "costCenter: cc-platform", "dataClassification: internal"]:
        require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", label)
    require_contains("backstage/app/app-config.yaml", "platformRepositoryUrl:")
    require_contains("backstage/app/app-config.yaml", "platformRepositoryOwner:")
    require_contains("backstage/app/app-config.yaml", "platformRepositoryName:")
    require_contains("backstage/deploy/templates/configmap.yaml", "platformRepositoryUrl:")
    require_contains("backstage/deploy/templates/configmap.yaml", "platformRepositoryOwner:")
    require_contains("backstage/deploy/templates/configmap.yaml", "platformRepositoryName:")
    require_contains("infrastructure/terraform/platform/gitops.tf", "platform_repository_url")
    for needle in [
        "deployment-values:",
        "BACKSTAGE_IMAGE_DIGEST_REF",
        "BACKSTAGE_CATALOG_RECONCILER_IMAGE_DIGEST_REF",
        "BACKSTAGE_CHART_DIGEST_REF",
        "Backstage platform Terraform inputs",
        "run_azure_smoke:",
        "Deployed Backstage smoke",
        "scripts/azure/validate_stage09_azure.sh",
        "runs-on: [self-hosted, azure, private-acr, swedencentral]",
        "github.ref == 'refs/heads/main'",
        "BACKSTAGE_TRUST_PRIVATE_CA",
        "BACKSTAGE_TLS_CA_KEY_VAULT_NAME",
        "BACKSTAGE_RESOLVE_IP",
        "AZURE_CONFIG_DIR:",
        "Remove Azure CLI cache",
        '"enable_backstage": true',
        '"enable_gitops": true',
        '"enable_techdocs_storage": true',
    ]:
        require_contains(".github/workflows/ci-backstage.yml", needle)
    for needle in [
        'jq -r \'.oidc\'',
        'jq -r \'.workloadIdentity\'',
        "for tool in az curl jq",
        "BACKSTAGE_TRUST_PRIVATE_CA must be true or false.",
        "Backstage readiness TLS verification uses private CA from Key Vault.",
        'TechDocs storage public network access is not disabled.',
        'TechDocs container exists.',
        'Approved TechDocs private endpoints:',
    ]:
        require_contains("scripts/azure/validate_stage09_azure.sh", needle)


def validate_gitops() -> None:
    base_kustomization = read("platform-gitops/clusters/_base/addon-config/kustomization.yaml")
    if "backstage/kustomization.yaml" in base_kustomization:
        fail("Backstage must not be part of the Stage 07/08 base addon-config; enable_backstage uses a dedicated Flux configuration")
    for overlay in ["demo", "nonprod", "prod"]:
        require_contains(f"platform-gitops/clusters/overlays/{overlay}/backstage/kustomization.yaml", "../../../_base/addon-config/backstage")
    require_contains("platform-gitops/clusters/overlays/demo/backstage/kustomization.yaml", "platform-private-ca")
    for expected in [
        "namespace.yaml",
        "flux-applier-rbac.yaml",
        "serviceaccount.yaml",
        "secretstore.yaml",
        "runtime-externalsecret.yaml",
        "ocirepository.yaml",
        "helmrelease.yaml",
        "rbac-groups-configmap.yaml",
        "secretproviderclass.yaml",
        "catalog-reconciler",
    ]:
        require_contains("platform-gitops/clusters/_base/addon-config/backstage/kustomization.yaml", expected)
    for expected in ["backstage_client_id", "backstage_chart_digest", "backstage_image_digest", "platform_acr_login_server", "techdocs_storage_account_name"]:
        require_contains("infrastructure/terraform/platform/gitops.tf", expected)
    for expected in [
        "backstage_workload_identity_client_id",
        "backstage_workload_identity_principal_id",
        "backstage_catalog_reconciler_workload_identity_client_id",
        "backstage_catalog_reconciler_workload_identity_principal_id",
    ]:
        require_contains("infrastructure/terraform/platform/workload-identities.tf", expected)
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "create: false")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "serviceAccountName: flux-applier")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/flux-applier-rbac.yaml", "backstage-helm-manager")
    for resource in ["deployments", "replicasets", "services", "configmaps", "horizontalpodautoscalers", "ingresses", "networkpolicies", "poddisruptionbudgets"]:
        require_contains("platform-gitops/clusters/_base/addon-config/backstage/flux-applier-rbac.yaml", resource)
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/flux-applier-rbac.yaml", "platform:tenant-helm-release-storage")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/flux-applier-rbac.yaml", "name: flux-applier")
    backstage_addon_dir = ROOT / "platform-gitops/clusters/_base/addon-config/backstage"
    if any("serviceaccounts/token" in path.read_text(encoding="utf-8") for path in backstage_addon_dir.glob("*.yaml")):
        fail("Backstage GitOps must not grant namespace token minting to source-controller")
    if "serviceAccountName:" in read("platform-gitops/clusters/_base/addon-config/backstage/ocirepository.yaml"):
        fail("Backstage OCIRepository uses controller-level Flux Workload Identity and must not set serviceAccountName")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/ocirepository.yaml", "digest: ${backstage_chart_digest}")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "backstage_aks_apiserver_url")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "postgresAuthMode: ${backstage_postgres_auth_mode}")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/helmrelease.yaml", "${platform_profile}.backstage.${platform_root_domain}")
    require_contains("infrastructure/terraform/platform/variables.tf", 'variable "backstage_postgres_auth_mode"')
    require_contains("backstage/deploy/templates/deployment.yaml", "command:")
    require_contains("backstage/deploy/templates/deployment.yaml", "scripts/start-backstage.mjs")
    require_contains("backstage/deploy/templates/deployment.yaml", "mountPath: /tmp")
    require_contains("backstage/deploy/templates/deployment.yaml", "backstage.io/kubernetes-id: backstage")
    require_contains("backstage/deploy/values.yaml", "--no-node-snapshot --max-old-space-size=512")
    require_contains("backstage/deploy/templates/deployment.yaml", "BACKSTAGE_SESSION_SECRET")
    require_contains("backstage/deploy/templates/deployment.yaml", "BACKSTAGE_MICROSOFT_AUTH_CLIENT_SECRET")
    require_contains("backstage/deploy/templates/configmap.yaml", "type: jwks")
    require_contains("backstage/deploy/templates/configmap.yaml", "audience: backstage")
    require_contains("backstage/deploy/templates/configmap.yaml", 'subjectPrefix: "system:serviceaccount:backstage:"')
    require_contains("backstage/deploy/templates/deployment.yaml", "/.backstage/health/v1/readiness")
    require_contains("backstage/deploy/templates/deployment.yaml", "/.backstage/health/v1/liveness")
    require_contains("backstage/deploy/templates/deployment.yaml", "configMapKeyRef")
    require_contains("backstage/deploy/templates/networkpolicy.yaml", "backstage-catalog-reconciler")
    require_contains("backstage/deploy/templates/configmap.yaml", "platformAdminsGroupRef")
    require_contains("backstage/deploy/templates/configmap.yaml", "accessRestrictions")
    require_contains("backstage/deploy/templates/configmap.yaml", "secret: ${BACKSTAGE_SESSION_SECRET}")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/runtime-externalsecret.yaml", "backstage-session-secret")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/runtime-externalsecret.yaml", "backstage-microsoft-auth-client-secret")
    require_contains("backstage/app/scripts/start-backstage.mjs", "https://ossrdbms-aad.database.windows.net/.default")
    require_contains("backstage/app/scripts/start-backstage.mjs", "expiresIn - 300")
    require_contains("backstage/app/scripts/start-backstage.mjs", "Math.random()")
    require_contains("backstage/app/scripts/start-backstage.mjs", "currentChild?.kill")
    require_contains("backstage/deploy/templates/deployment.yaml", "POSTGRES_PASSWORD_FILE")
    require_contains("backstage/deploy/templates/deployment.yaml", "/mnt/secrets-store/password")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/secretproviderclass.yaml", "objectAlias: password")
    require_contains("backstage/deploy/templates/deployment.yaml", "backstage-postgres-fallback")
    if "postgres-password" in read("platform-gitops/clusters/_base/addon-config/backstage/runtime-externalsecret.yaml"):
        fail("Default Backstage runtime ExternalSecret must not require the Postgres password fallback secret")
    require_contains("backstage/catalog-reconciler/reconciler.py", "platform.example.io/team")
    require_contains("backstage/catalog-reconciler/reconciler.py", "platform-drift")
    require_contains("backstage/catalog-reconciler/reconciler.py", "BACKSTAGE_SERVICE_TOKEN_FILE")
    require_contains("backstage/catalog-reconciler/reconciler.py", "TEAMS_WEBHOOK_URL")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/externalsecret.yaml", "teams-webhook-url")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml", "backstage_catalog_reconciler_image_digest")
    require_contains("backstage/catalog-reconciler/reconciler.py", "rel=\"next\"")
    require_contains("backstage/catalog-reconciler/reconciler.py", "backstage.io/kubernetes-id")
    require_contains("backstage/catalog-reconciler/reconciler.py", "backstage.io/managed-by-origin-location")
    require_contains("backstage/catalog-reconciler/reconciler.py", "OWNER_PREFIX")
    require_contains("backstage/catalog-reconciler/Dockerfile", "COPY --chown=65532:65532 reconciler.py")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/networkpolicy.yaml", "backstage-catalog-reconciler")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/secretstore.yaml", "backstage-catalog-reconciler")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml", "https://${platform_profile}.backstage.${platform_root_domain}")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml", "serviceAccountToken")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/rbac-groups-configmap.yaml", 'applicationTeamGroupRefs: "${backstage_application_team_group_refs}"')
    require_contains("infrastructure/terraform/platform/gitops.tf", "azurerm_role_assignment.backstage_key_vault_secret_user")
    require_contains("infrastructure/terraform/platform/gitops.tf", "azurerm_role_assignment.techdocs_backstage_writer")
    if "docker.io/library/python" in read("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml"):
        fail("Catalog reconciler must use a signed platform image, not Docker Hub python")
    for expected in ["BACKSTAGE_BASE_URL", "GITHUB_ORG"]:
        require_contains("platform-gitops/clusters/_base/addon-config/backstage/catalog-reconciler/cronjob.yaml", expected)

    rendered_demo_backstage = render_kustomize("platform-gitops/clusters/overlays/demo/backstage")
    for expected in [
        "clusterIssuer: platform-private-ca",
        "host: ${platform_profile}.backstage.${platform_root_domain}",
        "baseUrl: https://${platform_profile}.backstage.${platform_root_domain}",
        "value: http://backstage.backstage.svc.cluster.local:7007",
        "port: 7007",
    ]:
        if expected not in rendered_demo_backstage:
            fail(f"Rendered demo Backstage overlay must contain {expected!r}")


def validate_terraform() -> None:
    for path in [
        "infrastructure/terraform/platform/variables.tf",
        "infrastructure/terraform/platform/locals.tf",
        "infrastructure/terraform/platform/main.tf",
        "infrastructure/terraform/platform/outputs.tf",
        "infrastructure/terraform/platform/techdocs.tf",
    ]:
        require_file(path)

    for needle in [
        'variable "enable_techdocs_storage"',
        'variable "enable_backstage"',
        'variable "backstage_chart_digest"',
        'variable "backstage_cost_showback_container_url"',
        'variable "backstage_cost_showback_container_id"',
        'variable "backstage_workload_identity_principal_id"',
        'variable "backstage_microsoft_auth_client_id"',
        'variable "backstage_catalog_reconciler_workload_identity_client_id"',
        'variable "backstage_catalog_reconciler_workload_identity_principal_id"',
        'variable "backstage_application_team_group_refs"',
        'variable "backstage_application_team_group_map_json"',
        'variable "backstage_microsoft_graph_group_object_ids"',
        'variable "techdocs_publisher_principal_ids"',
        'variable "backstage_image_digest"',
        'variable "backstage_catalog_reconciler_image_digest"',
    ]:
        require_contains("infrastructure/terraform/platform/variables.tf", needle)
    for needle in [
        "azurerm_storage_account.techdocs",
        "azurerm_storage_container.techdocs",
        "Storage Blob Data Reader",
        "Storage Blob Data Contributor",
        "shared_access_key_enabled         = false",
        "public_network_access_enabled     = false",
    ]:
        require_contains("infrastructure/terraform/platform/techdocs.tf", needle)
    require_contains("infrastructure/terraform/platform/locals.tf", "privatelink.blob.core.windows.net")
    require_contains("infrastructure/terraform/platform/locals.tf", "techdocs_storage_name")
    require_contains("infrastructure/terraform/platform/locals.tf", "techdocs")
    require_contains("infrastructure/terraform/platform/locals.tf", "blobServices/default")
    require_contains("infrastructure/terraform/platform/outputs.tf", "techdocs_storage_account_name")
    require_contains("infrastructure/terraform/platform/outputs.tf", "backstage_flux_configuration_id")
    require_contains("infrastructure/terraform/platform/main.tf", "enable_gitops requires platform_root_domain")
    require_contains("infrastructure/terraform/platform/main.tf", "enable_techdocs_storage requires enable_private_endpoints")
    require_contains("infrastructure/terraform/platform/aks.tf", "Azure Kubernetes Service Cluster User Role")
    require_contains("infrastructure/terraform/platform/aks.tf", "Azure Kubernetes Service RBAC Reader")
    require_contains("infrastructure/terraform/platform/acr.tf", "flux_source_acr_pull")
    require_contains("infrastructure/terraform/platform/acr.tf", "local.gitops_enabled && var.enable_acr")
    require_contains("infrastructure/terraform/platform/key-vault.tf", "backstage_key_vault_secret_user")
    require_contains("infrastructure/terraform/platform/key-vault.tf", "backstage_catalog_reconciler_key_vault_secret_user")
    require_contains("infrastructure/terraform/platform/key-vault.tf", "/secrets/")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/secretstore.yaml", "name: backstage")
    require_contains("infrastructure/terraform/platform/finops.tf", "backstage_cost_showback_reader")
    require_contains("backstage/app/packages/backend/src/index.ts", "platformCostShowback")
    require_contains("backstage/app/packages/app/src/App.tsx", "costInsightsApiRef")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "applicationTeamGroupMap")
    require_contains("platform-gitops/clusters/_base/addon-config/backstage/rbac-groups-configmap.yaml", "applicationTeamGroupMap: >-")
    require_contains("infrastructure/terraform/platform/gitops.tf", "backstage_microsoft_graph_group_filter")
    require_contains("backstage/deploy/templates/configmap.yaml", "BACKSTAGE_MICROSOFT_GRAPH_GROUP_FILTER")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "rawTeamGroupMap.startsWith('json:')")
    require_contains("backstage/app/app-config.yaml", "userGroupMember:")
    require_contains("backstage/app/app-config.yaml", "BACKSTAGE_MICROSOFT_GRAPH_GROUP_FILTER")
    require_contains("infrastructure/terraform/platform/locals.tf", "var.postgres_administrator_login")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "httpAuth.credentials")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "userInfoService.getUserInfo")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "blob.name.endsWith('.csv')")
    if "plugin-mcp-actions-backend" in read("backstage/app/packages/backend/src/index.ts"):
        fail("MCP actions backend must not be enabled for the Stage 09 MVP")
    require_contains(".github/workflows/ci-backstage.yml", "platform/backstage-catalog-reconciler")
    require_contains(".github/rulesets/main-branch-protection.json", "Backstage app contract (22.x)")
    require_contains("infrastructure/terraform/platform/gitops.tf", "backstage_cost_showback_url")
    require_contains("backstage/app/packages/backend/src/plugins/platformCostShowback.ts", "slice(0, 10)")
    if (ROOT / "platform-gitops/clusters/_base/addon-config/backstage/clusterrole.yaml").exists():
        fail("Backstage Kubernetes access is governed by Azure RBAC; do not add ineffective in-cluster ClusterRole")


def validate_workflows_and_docs() -> None:
    for needle in ["container-build-sign.yml", "helm-publish.yml", "backstage/app", "backstage/deploy"]:
        require_contains(".github/workflows/ci-backstage.yml", needle)
    require_contains("docs/runbooks/README.md", "backstage-ops.md")
    for adr in ["0020-build-vs-buy.md", "0041-backstage-rbac.md", "0042-techdocs-storage.md", "0052-backstage-postgres-auth.md"]:
        require_contains(f"docs/adr/{adr}", "Status: accepted")
        require_contains(f"docs/adr/{adr}", "Stage 09")
    require_contains("docs/adr/README.md", "0041 | Backstage RBAC | Accepted")
    require_contains("scripts/azure/validate_stage09_azure.sh", "az storage account show")
    require_contains("scripts/azure/validate_stage09_azure.sh", "az aks show")


def main() -> None:
    for path in EXPECTED_FILES:
        require_file(path)
    validate_backstage_config()
    validate_permissions()
    validate_gitops()
    validate_terraform()
    validate_workflows_and_docs()
    print("Stage 09 Backstage MVP contracts validated.")


if __name__ == "__main__":
    main()
