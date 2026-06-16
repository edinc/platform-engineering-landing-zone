#!/usr/bin/env python3
"""Validate Stage 10 generated egress exception patch requests."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any
import yaml


ROOT = Path(__file__).resolve().parents[2]
PATCH_DIR = Path(os.environ.get("EGRESS_PATCH_DIR", ROOT / "policies/azure/firewall/exception-patches"))
ALLOWLIST = Path(os.environ.get("EGRESS_ALLOWLIST", ROOT / "policies/azure/firewall/allowlist.json"))
OVERLAYS_DIR = Path(os.environ.get("EGRESS_OVERLAYS_DIR", ROOT / "platform-gitops/clusters/overlays"))
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,78}[a-z0-9]$")
FQDN_RE = re.compile(r"^(\*\.)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$")


def require(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        errors.append(message)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}


def patch_fqdns(patch: dict) -> list[str]:
    fqdns: list[str] = []
    for rule in patch.get("collection", {}).get("rules", []):
        for fqdn in rule.get("destination_fqdns", []):
            if isinstance(fqdn, str):
                fqdns.append(fqdn)
    return sorted(set(fqdns))


def fqdn_match_entries(fqdns: list[str]) -> list[dict[str, str]]:
    entries = []
    for fqdn in fqdns:
        if fqdn.startswith("*."):
            entries.append({"matchPattern": fqdn})
        else:
            entries.append({"matchName": fqdn})
    return entries


def validate_cilium_policy(policy_path: Path, patch: dict, environment: str, errors: list[str]) -> None:
    policy = load_yaml(policy_path)
    metadata = patch.get("collection", {}).get("metadata", {})
    expected_name = f"egress-{patch.get('collection', {}).get('name', '').removeprefix('team-')}"
    expected_fqdns = patch_fqdns(patch)
    expected_fqdn_entries = fqdn_match_entries(expected_fqdns)

    require(policy.get("apiVersion") == "cilium.io/v2", errors, f"{policy_path}: apiVersion must be cilium.io/v2")
    require(policy.get("kind") == "CiliumNetworkPolicy", errors, f"{policy_path}: kind must be CiliumNetworkPolicy")
    policy_metadata = policy.get("metadata", {})
    require(policy_metadata.get("name") == expected_name, errors, f"{policy_path}: metadata.name must match patch collection name")
    require(policy_metadata.get("namespace") == metadata.get("namespace"), errors, f"{policy_path}: metadata.namespace must match patch metadata.namespace")
    require(policy_metadata.get("labels", {}).get("platform.example.io/team") == metadata.get("team"), errors, f"{policy_path}: team label must match patch metadata.team")
    require(policy_metadata.get("annotations", {}).get("platform.example.io/expires-on") == metadata.get("expiresOn"), errors, f"{policy_path}: expires-on annotation must match patch metadata.expiresOn")

    spec = policy.get("spec", {})
    selector = spec.get("endpointSelector")
    require(isinstance(selector, dict) and selector.get("matchLabels"), errors, f"{policy_path}: endpointSelector.matchLabels is required")
    egress = spec.get("egress")
    require(isinstance(egress, list) and len(egress) == 2, errors, f"{policy_path}: egress must contain exactly DNS and FQDN rules")
    if not isinstance(egress, list) or len(egress) != 2:
        return

    dns_rule, fqdn_rule = egress
    disallowed_keys = {"toCIDR", "toCIDRSet", "toEntities", "toServices", "toGroups", "toNodes"}
    for index, rule in enumerate(egress):
        extra = sorted(disallowed_keys & set(rule))
        require(not extra, errors, f"{policy_path}: egress[{index}] contains disallowed keys: {', '.join(extra)}")

    dns_entries = dns_rule.get("toPorts", [{}])[0].get("rules", {}).get("dns", [])
    require(dns_entries == expected_fqdn_entries, errors, f"{policy_path}: DNS rules must match patch destination_fqdns")
    require(fqdn_rule.get("toFQDNs") == expected_fqdn_entries, errors, f"{policy_path}: toFQDNs must match patch destination_fqdns")
    to_ports = fqdn_rule.get("toPorts")
    require(
        to_ports == [{"ports": [{"port": "443", "protocol": "TCP"}]}],
        errors,
        f"{policy_path}: FQDN egress ports must be TCP/443 only",
    )


def validate_patch(path: Path, today: date, errors: list[str]) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path}: invalid JSON: {exc}")
        return

    collection = data.get("collection")
    require(data.get("applyTo") == "policies/azure/firewall/allowlist.json", errors, f"{path}: applyTo must target policies/azure/firewall/allowlist.json")
    require(isinstance(collection, dict), errors, f"{path}: collection must be an object")
    if not isinstance(collection, dict):
        return

    require(isinstance(collection.get("name"), str) and NAME_RE.match(collection["name"]) is not None, errors, f"{path}: collection.name must be kebab-case")
    require(isinstance(collection.get("priority"), int) and 800 <= collection["priority"] <= 899, errors, f"{path}: collection.priority must be 800-899")
    require(collection.get("action") == "Allow", errors, f"{path}: collection.action must be Allow")

    metadata = collection.get("metadata")
    require(isinstance(metadata, dict), errors, f"{path}: collection.metadata must be an object")
    if isinstance(metadata, dict):
        expires_on = metadata.get("expiresOn")
        try:
            expiry = datetime.strptime(str(expires_on), "%Y-%m-%d").replace(tzinfo=timezone.utc).date()
        except ValueError:
            errors.append(f"{path}: metadata.expiresOn must be YYYY-MM-DD")
        else:
            require(expiry >= today, errors, f"{path}: metadata.expiresOn must not be in the past")
            require((expiry - today).days <= 90, errors, f"{path}: metadata.expiresOn must be within 90 days")
        for key in ["team", "namespace", "dataClassification", "businessJustification"]:
            require(isinstance(metadata.get(key), str) and metadata[key], errors, f"{path}: metadata.{key} is required")

    rules = collection.get("rules")
    require(isinstance(rules, list) and rules, errors, f"{path}: collection.rules must be non-empty")
    for index, rule in enumerate(rules or []):
        rule_path = f"{path}: collection.rules[{index}]"
        require(isinstance(rule, dict), errors, f"{rule_path} must be an object")
        if not isinstance(rule, dict):
            continue
        require(isinstance(rule.get("name"), str) and NAME_RE.match(rule["name"]) is not None, errors, f"{rule_path}.name must be kebab-case")
        fqdns = rule.get("destination_fqdns")
        require(isinstance(fqdns, list) and fqdns, errors, f"{rule_path}.destination_fqdns must be non-empty")
        for fqdn in fqdns or []:
            require(isinstance(fqdn, str) and fqdn != "*" and FQDN_RE.match(fqdn) is not None, errors, f"{rule_path}: invalid FQDN {fqdn!r}")
        protocols = rule.get("protocols")
        require(isinstance(protocols, list) and protocols, errors, f"{rule_path}.protocols must be non-empty")
        for protocol in protocols or []:
            require(protocol == {"type": "Https", "port": 443}, errors, f"{rule_path}.protocols entries must be HTTPS/443")


def comparable_collection(collection: dict) -> dict:
    return {
        key: collection.get(key)
        for key in ["name", "priority", "action", "rules"]
    }


def allowlist_collections() -> dict[str, dict]:
    if not ALLOWLIST.exists():
        return {}
    return {
        str(collection.get("name")): comparable_collection(collection)
        for collection in load_json(ALLOWLIST).get("application_rule_collections", [])
        if collection.get("name")
    }


def policy_dir(environment: str) -> Path:
    return OVERLAYS_DIR / environment / "network/egress-exceptions"


def kustomization_path(environment: str) -> Path:
    override = os.environ.get("EGRESS_KUSTOMIZATION")
    if override:
        return Path(override)
    return policy_dir(environment) / "kustomization.yaml"


def kustomization_resources(environment: str) -> set[str]:
    path = kustomization_path(environment)
    if not path.exists():
        return set()
    resources: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            resources.add(stripped[2:])
    return resources


def validate_patch_wiring(errors: list[str]) -> None:
    collections = allowlist_collections()
    for path in sorted(PATCH_DIR.glob("*.json")) if PATCH_DIR.exists() else []:
        try:
            patch = load_json(path)
        except json.JSONDecodeError:
            continue
        metadata = patch.get("collection", {}).get("metadata", {})
        namespace = str(metadata.get("namespace", ""))
        environment = namespace.rsplit("-", 1)[-1]
        if environment not in {"demo", "nonprod", "prod"}:
            errors.append(f"{path}: metadata.namespace must end with -demo, -nonprod, or -prod")
            continue
        resources = kustomization_resources(environment)
        collection_name = str(patch.get("collection", {}).get("name", ""))
        policy_filename = f"{path.stem}.yaml"
        if collection_name:
            require(collection_name in collections, errors, f"{path}: matching collection {collection_name!r} must be applied to policies/azure/firewall/allowlist.json")
            if collection_name in collections:
                expected = comparable_collection(patch.get("collection", {}))
                require(collections[collection_name] == expected, errors, f"{path}: allowlist collection {collection_name!r} must match patch name, priority, action, and rules exactly")
        policy_path = policy_dir(environment) / policy_filename
        require(policy_path.exists(), errors, f"{path}: matching {environment} Cilium policy {policy_filename} is missing")
        require(policy_filename in resources, errors, f"{path}: {policy_filename} must be listed in {kustomization_path(environment).relative_to(ROOT)}")
        if policy_path.exists():
            validate_cilium_policy(policy_path, patch, environment, errors)


def validate_unique_patch_priorities(errors: list[str]) -> None:
    seen: dict[int, Path] = {}
    for path in sorted(PATCH_DIR.glob("*.json")) if PATCH_DIR.exists() else []:
        try:
            priority = load_json(path).get("collection", {}).get("priority")
        except json.JSONDecodeError:
            continue
        if not isinstance(priority, int):
            continue
        if priority in seen:
            errors.append(f"{path}: priority {priority} duplicates {seen[priority]}")
        seen[priority] = path


def main() -> int:
    if not PATCH_DIR.exists():
        print("No egress exception patch directory found; skipping.")
        return 0

    errors: list[str] = []
    today = datetime.now(timezone.utc).date()
    for path in sorted(PATCH_DIR.glob("*.json")):
        validate_patch(path, today, errors)
    validate_unique_patch_priorities(errors)
    validate_patch_wiring(errors)

    if errors:
        print("Egress exception patch checks FAILED:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Egress exception patch checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
