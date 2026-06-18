#!/usr/bin/env python3
"""Validate Stage 10 multi-tenancy and onboarding repository contracts."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

EXPECTED_FILES = [
    ".github/workflows/onboard-team.yml",
    "templates/onboard-team/template.yaml",
    "templates/onboard-team/skeleton/vending/requests/teams/${{ values.teamName }}.yaml",
    "templates/request-egress-exception/template.yaml",
    "templates/request-egress-exception/skeleton/policies/azure/firewall/exception-patches/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.json",
    "templates/request-egress-exception/skeleton/platform-gitops/clusters/overlays/${{ values.environment }}/network/egress-exceptions/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.yaml",
    "docs/contracts/team-onboarding-request.schema.json",
    "docs/contracts/examples/team-onboarding-request.yaml",
    "docs/contracts/vending-request.schema.json",
    "scripts/workflows/validate_team_onboarding_request.py",
    "scripts/policy/validate_egress_exception_patches.py",
    "scripts/policy/sweep_expired_egress_exceptions.py",
    ".github/workflows/egress-exception-sweep.yml",
    "infrastructure/terraform/team-onboarding/main.tf",
    "infrastructure/terraform/team-onboarding/variables.tf",
    "infrastructure/terraform/team-onboarding/outputs.tf",
    "policies/backstage/ownership-required.ts",
    "docs/runbooks/ownership-matrix.md",
    "docs/runbooks/team-onboarding.md",
    "docs/runbooks/team-decommissioning.md",
    "docs/adr/0018-inner-loop.md",
    "docs/adr/0043-ownership-matrix.md",
    "scripts/test/onboarding-smoke.sh",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_file(path: str) -> None:
    if not (ROOT / path).is_file():
        fail(f"Required Stage 10 file missing: {path}")


def require_contains(path: str, needle: str) -> None:
    if needle not in read(path):
        fail(f"{path} must contain {needle!r}")


def validate_templates() -> None:
    onboard = read("templates/onboard-team/template.yaml")
    for needle in [
        "name: onboard-team",
        "teamName:",
        "productName:",
        "costCenter:",
        "onCallRotationId:",
        "githubTeam:",
        "dataClassification:",
        "teamScopedTemplate",
        "publish:github:pull-request",
        "TeamOnboardingRequest",
    ]:
        if needle not in onboard and needle not in read(
            "templates/onboard-team/skeleton/vending/requests/teams/${{ values.teamName }}.yaml"
        ):
            fail(f"onboard-team template must include {needle!r}")

    egress = read("templates/request-egress-exception/template.yaml")
    for needle in [
        "name: request-egress-exception",
        "destinationFqdns:",
        "firewallPriority:",
        "productName:",
        "appSelector:",
        "expiresOn:",
        "teamScopedTemplate",
        "publish:github:pull-request",
        "maximum 90 days",
    ]:
        require_contains("templates/request-egress-exception/template.yaml", needle)
    require_contains(
        "templates/request-egress-exception/skeleton/policies/azure/firewall/exception-patches/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.json",
        '"applyTo": "policies/azure/firewall/allowlist.json"',
    )
    require_contains(
        "templates/request-egress-exception/skeleton/policies/azure/firewall/exception-patches/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.json",
        "team-${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}",
    )
    require_contains(
        "templates/request-egress-exception/skeleton/platform-gitops/clusters/overlays/${{ values.environment }}/network/egress-exceptions/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.yaml",
        "kind: CiliumNetworkPolicy",
    )
    require_contains(
        "templates/request-egress-exception/skeleton/platform-gitops/clusters/overlays/${{ values.environment }}/network/egress-exceptions/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.yaml",
        "startsWith('*.')",
    )
    require_contains(
        "templates/request-egress-exception/skeleton/platform-gitops/clusters/overlays/${{ values.environment }}/network/egress-exceptions/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.yaml",
        "app.kubernetes.io/name",
    )
    require_contains(
        "templates/request-egress-exception/skeleton/platform-gitops/clusters/overlays/${{ values.environment }}/network/egress-exceptions/${{ values.teamName }}-${{ values.environment }}-${{ values.exceptionSlug }}.yaml",
        "matchName",
    )
    require_contains("templates/request-egress-exception/template.yaml", "pattern: \"^[A-Za-z0-9]")
    for path in [
        "templates/onboard-team/template.yaml",
        "templates/request-egress-exception/template.yaml",
    ]:
        require_contains(path, "platformRepoUrl:")
        require_contains(path, "repoUrl: ${{ parameters.platformRepoUrl }}")
        if "RepoUrlPicker" in read(path):
            fail(f"{path} must not let app teams pick arbitrary repositories")
    require_contains("backstage/app/app-config.yaml", "templates/onboard-team/template.yaml")
    require_contains("backstage/app/app-config.yaml", "templates/request-egress-exception/template.yaml")
    require_contains("backstage/deploy/templates/configmap.yaml", "templates/onboard-team/template.yaml")
    require_contains("backstage/deploy/templates/configmap.yaml", "templates/request-egress-exception/template.yaml")
    for path in ["backstage/app/app-config.yaml", "backstage/deploy/templates/configmap.yaml"]:
        text = read(path)
        if "githubDiscovery:" in text and "allow: [Component, System, API, Resource, Domain, Template]" in text:
            fail(f"{path} must not import Template entities through org-wide GitHub discovery")
    if "Telepresence" in onboard or "Telepresence" in egress:
        fail("Stage 10 templates must not make Telepresence a supported dependency")


def validate_policy() -> None:
    policy = read("backstage/app/packages/backend/src/plugins/platformPermissionPolicy.ts")
    for needle in [
        "actionExecutePermission",
        "taskCreatePermission",
        "templateParameterReadPermission",
        "templateStepReadPermission",
        "createScaffolderActionConditionalDecision",
        "createScaffolderTaskConditionalDecision",
        "createScaffolderTemplateConditionalDecision",
        "values.teamScopedTemplate",
        "values.teamName",
        "fetch:template",
        "publish:github:pull-request",
        "platformRepositoryUrl",
        "platformRepositoryOwner",
        "platformRepositoryName",
        "taskReadPermission",
        "taskCancelPermission",
        "applicationTeamGroupMap",
    ]:
        require_contains("backstage/app/packages/backend/src/plugins/platformPermissionPolicy.ts", needle)

    ownership_rule = read("policies/backstage/ownership-required.ts")
    for needle in [
        "validateOwnershipRequired",
        "assertOwnershipRequired",
        "entity.kind !== 'Component'",
        "OWNER_REF_PATTERN",
        "spec.owner",
    ]:
        if needle not in ownership_rule:
            fail(f"ownership-required policy must include {needle!r}")

    require_contains("policies/backstage/permissions.ts", "validateOwnershipRequired")


def validate_catalog_ownership() -> None:
    component_re = re.compile(
        r"(?ms)^kind:\s*Component\s*$.*?^spec:\s*$"
        r"(?P<spec>(?:^  [^\n]*\n|^\s*$)+)",
    )
    owner_re = re.compile(r"^  owner:\s+(group|user):default/[a-z0-9][a-z0-9_.-]*[a-z0-9]\s*$", re.MULTILINE)
    ignored_parts = {".git", ".tools", "node_modules", ".terraform", "skeleton"}

    for path in ROOT.rglob("*.yaml"):
        if any(part in ignored_parts for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8")
        for match in component_re.finditer(text):
            if not owner_re.search(match.group("spec")):
                fail(f"Backstage Component missing spec.owner in {path.relative_to(ROOT)}")


def validate_contracts_and_workflows() -> None:
    for needle in [
        "TeamOnboardingRequest",
        "githubTeam",
        "repositoryPermissions",
        '"enum": ["pull", "triage"]',
        '"maxLength": 22',
        '"pattern": "^[A-Za-z0-9_.-]+$"',
        "serviceAccountName",
        "egressAllowlist",
    ]:
        require_contains("docs/contracts/team-onboarding-request.schema.json", needle)
    require_contains("docs/contracts/vending-request.schema.json", "entraGroupObjectId")
    require_contains("docs/contracts/vending-request.schema.json", "192\\\\.168")
    if "entraGroupDisplayName" in read("docs/contracts/vending-request.schema.json"):
        fail("Namespace vending must use immutable entraGroupObjectId, not display names")
    require_contains("infrastructure/terraform/vending/aks-namespace/variables.tf", "RFC1918 IPv4 CIDRs")
    require_contains(".github/workflows/vend-namespace.yml", "entra_group_object_id: .spec.namespace.entraGroupObjectId")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "REPOSITORY_PERMISSIONS = {\"pull\", \"triage\"}")
    for overlay in ["demo", "nonprod", "prod"]:
        require_contains(f"platform-gitops/clusters/overlays/{overlay}/kustomization.yaml", "- network")
        require_contains(f"platform-gitops/clusters/overlays/{overlay}/network/kustomization.yaml", "- egress-exceptions")
    if (
        ROOT
        / "templates/request-egress-exception/skeleton/platform-gitops/clusters/_base/network/egress-exceptions/kustomization.yaml"
    ).exists():
        fail("request-egress-exception must not overwrite the shared egress-exceptions kustomization")
    require_contains("scripts/policy/validate_egress_exception_patches.py", "must be within 90 days")
    require_contains("scripts/policy/validate_egress_exception_patches.py", "validate_unique_patch_priorities")
    require_contains("scripts/policy/validate_egress_exception_patches.py", "validate_patch_wiring")
    require_contains("scripts/policy/validate_egress_exception_patches.py", "platform-gitops/clusters/overlays")
    require_contains("scripts/policy/validate_egress_exception_patches.py", "EGRESS_PATCH_DIR")
    require_contains("scripts/policy/sweep_expired_egress_exceptions.py", "remove_allowlist_collections")
    require_contains(".github/workflows/egress-exception-sweep.yml", "remove expired egress exceptions")

    workflow = read(".github/workflows/onboard-team.yml")
    for needle in [
        "infrastructure/terraform/team-onboarding",
        "PLATFORM_GITHUB_ADMIN_TOKEN",
        "validate_team_onboarding_request.py",
        "TEAM_ONBOARDING_APPROVED_REPOSITORIES",
        "PLATFORM_GITHUB_ADMIN_TOKEN_PRESENT",
        "GITHUB_TOKEN: ${{ secrets.PLATFORM_GITHUB_ADMIN_TOKEN }}",
        "GH_TOKEN: ${{ secrets.PLATFORM_GITHUB_ADMIN_TOKEN }}",
        "terraform apply",
        "Open namespace vending request PR",
        "github.ref == 'refs/heads/main'",
        "Privileged team onboarding runs only from main",
        "entraGroupObjectId",
        "x-access-token:${GH_TOKEN}",
        "git switch --detach",
    ]:
        if needle not in workflow:
            fail(f"onboard-team workflow must include {needle!r}")
    if "npx --yes js-yaml" in workflow or "npx --yes ajv-cli" in workflow:
        fail("Privileged onboard-team workflow must not execute npm packages at runtime")
    if re.search(r"(?m)^      GITHUB_TOKEN: \$\{\{ secrets\.PLATFORM_GITHUB_ADMIN_TOKEN \}\}", workflow):
        fail("PLATFORM_GITHUB_ADMIN_TOKEN must not be exported at job scope")
    for path in [
        ".github/workflows/onboard-team.yml",
        ".github/workflows/egress-exception-sweep.yml",
        ".github/workflows/vend-namespace.yml",
    ]:
        require_contains(path, "name:")
        subprocess.run(
            ["ruby", "-ryaml", "-e", f"YAML.load_file({str(ROOT / path)!r})"],
            check=True,
        )
    require_contains("infrastructure/terraform/team-onboarding/versions.tf", 'backend "azurerm" {}')
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "Composed namespace name <team>-<product>-<environment>")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "ipaddress.ip_network")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "RFC1918_NETWORKS")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "require_keys")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "spec.github.owner")
    require_contains(".github/workflows/onboard-team.yml", "TEAM_ONBOARDING_GITHUB_OWNER")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", "spec.githubTeam must equal app-team-<team>")
    require_contains("scripts/workflows/validate_team_onboarding_request.py", 'if "repositoryPermissions" in github else {}')
    require_contains(".github/workflows/onboard-team.yml", '"keyVaultSecretIds" => []')
    require_contains("docs/runbooks/team-onboarding.md", "backstage_application_team_group_refs")


def validate_terraform() -> None:
    for needle in [
        'resource "azuread_group" "app_team"',
        'resource "github_team" "app_team"',
        'resource "github_team_repository" "default_permissions"',
        "prevent_duplicate_names = true",
        'output "entra_group_object_id"',
        'output "cost_allocation"',
    ]:
        if needle not in read("infrastructure/terraform/team-onboarding/main.tf") and needle not in read(
            "infrastructure/terraform/team-onboarding/outputs.tf"
        ):
            fail(f"team-onboarding Terraform must include {needle!r}")
    require_contains("infrastructure/terraform/team-onboarding/variables.tf", "product_name must be a lowercase slug no longer than 22 characters")


def validate_docs() -> None:
    for path, needles in {
        "docs/runbooks/ownership-matrix.md": ["Management groups and ALZ policy", "AKS namespace", "Backstage Component"],
        "docs/runbooks/team-onboarding.md": ["Idempotency contract", "Partial failures", "scripts/test/onboarding-smoke.sh"],
        "docs/runbooks/team-decommissioning.md": ["Dry run", "Backstage Components", "Azure role assignments"],
        "docs/adr/0018-inner-loop.md": ["Tilt", "Bridge to Kubernetes", "Telepresence"],
        "docs/adr/0043-ownership-matrix.md": ["ownership-matrix.md", "spec.owner", "Stage 10"],
    }.items():
        for needle in needles:
            require_contains(path, needle)
    require_contains("docs/adr/README.md", "0018 | Developer inner loop | Accepted")
    require_contains("docs/adr/README.md", "0043 | Ownership matrix | Accepted")
    require_contains("docs/runbooks/README.md", "team-onboarding.md")


def main() -> None:
    for path in EXPECTED_FILES:
        require_file(path)
    validate_templates()
    validate_policy()
    validate_catalog_ownership()
    validate_contracts_and_workflows()
    validate_terraform()
    validate_docs()
    print("Stage 10 multi-tenancy contracts validated.")


if __name__ == "__main__":
    main()
