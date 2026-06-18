#!/usr/bin/env python3
"""Validate a TeamOnboardingRequest JSON payload without network dependencies."""

from __future__ import annotations

import json
import ipaddress
import os
import re
import sys
from pathlib import Path
from typing import Any


SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$")
TEAM_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$")
PRODUCT_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$")
COST_CENTER_RE = re.compile(r"^cc-[a-z0-9-]{2,32}$")
GITHUB_TEAM_RE = re.compile(r"^app-team-[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$")
GITHUB_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
ON_CALL_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{1,126}[A-Za-z0-9]$")
CPU_RE = re.compile(r"^[0-9]+m?$")
MEMORY_RE = re.compile(r"^[0-9]+(Mi|Gi)$")

ENVIRONMENTS = {"demo", "nonprod", "prod"}
DATA_CLASSIFICATIONS = {"public", "internal", "confidential", "restricted"}
REPOSITORY_PERMISSIONS = {"pull", "triage"}
RFC1918_NETWORKS = tuple(
    ipaddress.ip_network(cidr)
    for cidr in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
)
TOP_LEVEL_KEYS = {"apiVersion", "kind", "metadata", "spec"}
METADATA_KEYS = {"name", "labels"}
SPEC_KEYS = {
    "team",
    "product",
    "costCenter",
    "onCallRotationId",
    "githubTeam",
    "dataClassification",
    "environments",
    "regions",
    "github",
    "namespace",
}
GITHUB_KEYS = {"owner", "repositoryPermissions"}
NAMESPACE_KEYS = {"serviceAccountName", "resourceQuota", "egressAllowlist"}
QUOTA_KEYS = {"cpuRequests", "memoryRequests", "cpuLimits", "memoryLimits", "pods"}
EGRESS_KEYS = {"cidrs"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_keys(value: dict[str, Any], allowed: set[str], path: str) -> None:
    unknown = sorted(set(value) - allowed)
    require(not unknown, f"{path} contains unsupported keys: {', '.join(unknown)}")


def require_string(value: Any, path: str, pattern: re.Pattern[str] | None = None) -> str:
    require(isinstance(value, str) and value != "", f"{path} must be a non-empty string")
    if pattern:
        require(pattern.match(value) is not None, f"{path} has an invalid value")
    return value


def require_string_array(value: Any, path: str, allowed: set[str] | None = None) -> list[str]:
    require(isinstance(value, list) and len(value) > 0, f"{path} must be a non-empty list")
    require(len(value) == len(set(value)), f"{path} must not contain duplicates")
    items = [require_string(item, f"{path}[]") for item in value]
    if allowed:
        invalid = sorted(set(items) - allowed)
        require(not invalid, f"{path} contains unsupported values: {', '.join(invalid)}")
    return items


def require_private_cidr(value: str) -> None:
    try:
        network = ipaddress.ip_network(value, strict=False)
    except ValueError:
        fail(f"Invalid egress CIDR: {value}")
    require(network.version == 4, f"Egress CIDR must be IPv4: {value}")
    require(
        any(network.subnet_of(allowed) for allowed in RFC1918_NETWORKS),
        f"Egress CIDR must stay within RFC1918 private ranges: {value}",
    )
    require(network.prefixlen >= 16, f"Egress CIDR must be /16 or narrower; use request-egress-exception for broader access: {value}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        fail("Usage: validate_team_onboarding_request.py <request.json>")

    data = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    require(isinstance(data, dict), "request must be an object")
    require_keys(data, TOP_LEVEL_KEYS, "request")
    require(data.get("apiVersion") == "platform.example.io/v1alpha1", "apiVersion must be platform.example.io/v1alpha1")
    require(data.get("kind") == "TeamOnboardingRequest", "kind must be TeamOnboardingRequest")

    metadata = data.get("metadata")
    require(isinstance(metadata, dict), "metadata must be an object")
    require_keys(metadata, METADATA_KEYS, "metadata")
    require_string(metadata.get("name"), "metadata.name", SLUG_RE)

    spec = data.get("spec")
    require(isinstance(spec, dict), "spec must be an object")
    require_keys(spec, SPEC_KEYS, "spec")
    team = require_string(spec.get("team"), "spec.team", TEAM_RE)
    product = require_string(spec.get("product"), "spec.product", PRODUCT_RE)
    require_string(spec.get("costCenter"), "spec.costCenter", COST_CENTER_RE)
    require_string(spec.get("onCallRotationId"), "spec.onCallRotationId", ON_CALL_RE)
    github_team = require_string(spec.get("githubTeam"), "spec.githubTeam", GITHUB_TEAM_RE)
    require(github_team == f"app-team-{team}", "spec.githubTeam must equal app-team-<team>")
    require(spec.get("dataClassification") in DATA_CLASSIFICATIONS, "spec.dataClassification is invalid")
    environments = require_string_array(spec.get("environments"), "spec.environments", ENVIRONMENTS)
    for environment in environments:
        namespace_name = f"{team}-{product}-{environment}"
        require(len(namespace_name) <= 63, "Composed namespace name <team>-<product>-<environment> must be 63 characters or fewer")
    regions = require_string_array(spec.get("regions"), "spec.regions")
    for region in regions:
        require(re.match(r"^[a-z]+[a-z0-9]+$", region) is not None, f"Invalid Azure region token: {region}")

    github = spec.get("github")
    require(isinstance(github, dict), "spec.github must be an object")
    require_keys(github, GITHUB_KEYS, "spec.github")
    github_owner = require_string(github.get("owner"), "spec.github.owner", GITHUB_NAME_RE)
    expected_github_owner = os.environ.get("TEAM_ONBOARDING_GITHUB_OWNER")
    if expected_github_owner:
        require(
            github_owner == expected_github_owner,
            "spec.github.owner must match TEAM_ONBOARDING_GITHUB_OWNER",
        )
    repository_permissions = github["repositoryPermissions"] if "repositoryPermissions" in github else {}
    require(isinstance(repository_permissions, dict), "spec.github.repositoryPermissions must be an object")
    for repository, permission in repository_permissions.items():
        require_string(repository, "spec.github.repositoryPermissions key", GITHUB_NAME_RE)
        require(permission in REPOSITORY_PERMISSIONS, "repositoryPermissions may only grant pull or triage")

    namespace = spec.get("namespace")
    require(isinstance(namespace, dict), "spec.namespace must be an object")
    require_keys(namespace, NAMESPACE_KEYS, "spec.namespace")
    require_string(namespace.get("serviceAccountName"), "spec.namespace.serviceAccountName", SLUG_RE)

    quota = namespace.get("resourceQuota")
    require(isinstance(quota, dict), "spec.namespace.resourceQuota must be an object")
    require_keys(quota, QUOTA_KEYS, "spec.namespace.resourceQuota")
    require_string(quota.get("cpuRequests"), "spec.namespace.resourceQuota.cpuRequests", CPU_RE)
    require_string(quota.get("memoryRequests"), "spec.namespace.resourceQuota.memoryRequests", MEMORY_RE)
    require_string(quota.get("cpuLimits"), "spec.namespace.resourceQuota.cpuLimits", CPU_RE)
    require_string(quota.get("memoryLimits"), "spec.namespace.resourceQuota.memoryLimits", MEMORY_RE)
    pods = quota.get("pods")
    require(isinstance(pods, int) and 1 <= pods <= 500, "spec.namespace.resourceQuota.pods must be 1-500")

    egress = namespace.get("egressAllowlist")
    require(isinstance(egress, dict), "spec.namespace.egressAllowlist must be an object")
    require_keys(egress, EGRESS_KEYS, "spec.namespace.egressAllowlist")
    for cidr in require_string_array(egress.get("cidrs"), "spec.namespace.egressAllowlist.cidrs"):
        require_private_cidr(cidr)

    print("TeamOnboardingRequest contract validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
