#!/usr/bin/env python3
"""Validate reusable CI/CD workflow contracts without external dependencies."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_WORKFLOWS = {
    "container-build-sign.yml",
    "deploy-terraform-stack.yml",
    "gitops-push.yml",
    "helm-publish.yml",
    "import-quay.yml",
    "policy-checks.yml",
    "promote-image.yml",
    "techdocs-publish.yml",
    "terraform-plan-apply.yml",
}
SMOKE_WORKFLOW = "supply-chain-smoke.yml"

ACTION_REF_RE = re.compile(r"^\s*uses:\s+([^@\s#]+)@([^\s#]+)", re.MULTILINE)
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
TOP_LEVEL_KEY_RE = re.compile(r"^([A-Za-z][A-Za-z0-9 _-]*):", re.MULTILINE)
ALLOWED_TOP_LEVEL_KEYS = {"name", "on", "permissions", "concurrency", "env", "defaults", "jobs"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_workflow(name: str) -> None:
    path = ROOT / ".github" / "workflows" / name
    if not path.is_file():
        fail(f"Missing executable reusable workflow: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    if name == "deploy-terraform-stack.yml":
        if "workflow_dispatch:" not in text:
            fail(f"{path.relative_to(ROOT)} must expose on.workflow_dispatch")
    elif "workflow_call:" not in text:
        fail(f"{path.relative_to(ROOT)} must expose on.workflow_call")
    if name not in {"deploy-terraform-stack.yml", "import-quay.yml"} and "actions/checkout@" not in text:
        fail(f"{path.relative_to(ROOT)} must explicitly checkout the repository")
    if name != "deploy-terraform-stack.yml" and "step-security/harden-runner@" not in text:
        fail(f"{path.relative_to(ROOT)} must include harden-runner")
    top_level_keys = set(TOP_LEVEL_KEY_RE.findall(text))
    unexpected_keys = sorted(top_level_keys - ALLOWED_TOP_LEVEL_KEYS)
    if unexpected_keys:
        fail(
            f"{path.relative_to(ROOT)} contains unexpected top-level workflow keys: "
            f"{', '.join(unexpected_keys)}"
        )
    for action, ref in ACTION_REF_RE.findall(text):
        if action.startswith("./"):
            continue
        if not SHA_RE.fullmatch(ref):
            fail(
                f"{path.relative_to(ROOT)} uses mutable action ref {action}@{ref}; "
                "pin external actions to immutable commit SHAs"
            )


def validate_contract_stub(name: str) -> None:
    path = ROOT / "workflows" / name
    if not path.is_file():
        fail(f"Missing workflow contract record: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    expected = f"executable_location: .github/workflows/{name}"
    if "status: executable" not in text:
        fail(f"{path.relative_to(ROOT)} must be marked executable")
    if expected not in text:
        fail(f"{path.relative_to(ROOT)} must point to {expected}")


def validate_renovate() -> None:
    path = ROOT / "renovate.json"
    if not path.is_file():
        fail("Missing renovate.json")
    with path.open(encoding="utf-8") as handle:
        config = json.load(handle)
    if config.get("$schema") != "https://docs.renovatebot.com/renovate-schema.json":
        fail("renovate.json must declare the Renovate schema")
    if config.get("platformAutomerge") is not False:
        fail("renovate.json must keep platformAutomerge disabled for reviewed updates")
    if config.get("vulnerabilityAlerts", {}).get("enabled") is not False:
        fail("renovate.json must leave Renovate vulnerability alerts disabled")


def validate_smoke_workflow() -> None:
    path = ROOT / ".github" / "workflows" / SMOKE_WORKFLOW
    if not path.is_file():
        fail(f"Missing supply-chain smoke workflow: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    required_fragments = [
        "workflow_dispatch:",
        "./.github/workflows/container-build-sign.yml",
        "./.github/workflows/promote-image.yml",
        "samples/hello-container",
    ]
    for fragment in required_fragments:
        if fragment not in text:
            fail(f"{path.relative_to(ROOT)} must include {fragment}")


def validate_workflow_specific_contracts() -> None:
    container_build = (ROOT / ".github/workflows/container-build-sign.yml").read_text(encoding="utf-8")
    if "AZURE_CONFIG_DIR:" not in container_build:
        fail(".github/workflows/container-build-sign.yml must isolate Azure CLI state with AZURE_CONFIG_DIR")

    helm_publish = (ROOT / ".github/workflows/helm-publish.yml").read_text(encoding="utf-8")
    for fragment in [
        "outputs:",
        "chart_ref:",
        "digest_ref:",
        "value: ${{ jobs.publish.outputs.digest_ref }}",
        "digest_ref: ${{ steps.chart.outputs.digest_ref }}",
        "AZURE_CONFIG_DIR:",
        "pushed_ref=",
        "Unexpected pushed chart reference",
    ]:
        if fragment not in helm_publish:
            fail(f".github/workflows/helm-publish.yml must expose {fragment!r}")

    gitops_push = (ROOT / ".github/workflows/gitops-push.yml").read_text(encoding="utf-8")
    for fragment in [
        "image_digest_ref:",
        "acr_login_server:",
        "chart_digest_ref:",
        "sha256:REPLACE_WITH_SIGNED_CHART_DIGEST",
        "^sha256:[0-9a-f]{64}$",
        "AZURE_CONFIG_DIR:",
    ]:
        if fragment not in gitops_push:
            fail(f".github/workflows/gitops-push.yml must include {fragment!r}")

    terraform_plan_apply = (ROOT / ".github/workflows/terraform-plan-apply.yml").read_text(encoding="utf-8")
    for fragment in [
        "workflow_call:",
        "backend_container:",
        "tfvars_json_variable:",
        "tfvars_json_secret:",
        "vars[inputs.tfvars_json_variable]",
        "secrets[inputs.tfvars_json_secret]",
        "zz-workflow.auto.tfvars.json",
        "zz-workflow-secret.auto.tfvars.json",
        "AZURE_CONFIG_DIR:",
        "Remove materialized Terraform variables and Azure CLI cache",
        '"refs/heads/main"',
    ]:
        if fragment not in terraform_plan_apply:
            fail(f".github/workflows/terraform-plan-apply.yml must include {fragment!r}")
    if "workflow_dispatch:" in terraform_plan_apply:
        fail(".github/workflows/terraform-plan-apply.yml must not be directly manually dispatchable")

    deploy_terraform = (ROOT / ".github/workflows/deploy-terraform-stack.yml").read_text(encoding="utf-8")
    for fragment in [
        "workflow_dispatch:",
        "subscription-baseline",
        "connectivity",
        "identity",
        "cluster-state-repo",
        "platform",
        "./.github/workflows/terraform-plan-apply.yml",
        "profile:",
        "subscription_id:",
        "TERRAFORM_TFVARS_PLATFORM_SECRET_JSON",
    ]:
        if fragment not in deploy_terraform:
            fail(f".github/workflows/deploy-terraform-stack.yml must include {fragment!r}")
    for workflow_name in [
        "container-build-sign.yml",
        "gitops-push.yml",
        "helm-publish.yml",
        "promote-image.yml",
        "techdocs-publish.yml",
        "terraform-plan-apply.yml",
    ]:
        workflow_text = (ROOT / ".github/workflows" / workflow_name).read_text(encoding="utf-8")
        if "runs-on: [self-hosted, azure, private-acr, swedencentral]" not in workflow_text:
            fail(f".github/workflows/{workflow_name} must use the approved private Azure runner label set")


def main() -> None:
    for workflow in sorted(REQUIRED_WORKFLOWS):
        validate_workflow(workflow)
        validate_contract_stub(workflow)
    validate_smoke_workflow()
    validate_workflow_specific_contracts()
    validate_renovate()
    print("Reusable CI/CD workflow contracts validated.")


if __name__ == "__main__":
    main()
