#!/usr/bin/env python3
"""Validate the Stage 03 Azure Firewall FQDN allowlist.

The allowlist is consumed directly by Terraform, so this script keeps the JSON
shape deterministic and verifies that the minimum platform egress dependencies
from the Stage 03 roadmap remain covered. Stage 04 must intentionally extend the
network-rule validator when AKS node/control-plane egress is introduced.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REQUIRED_FQDNS = {
    "management.azure.com",
    "mcr.microsoft.com",
    "ghcr.io",
    "api.github.com",
    "github.com",
    "registry.npmjs.org",
    "pypi.org",
    "files.pythonhosted.org",
    "registry-1.docker.io",
    "auth.docker.io",
    "archive.ubuntu.com",
    "security.ubuntu.com",
    "rekor.sigstore.dev",
    "fulcio.sigstore.dev",
    "tuf.sigstore.dev",
}

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,78}[a-z0-9]$")
CIDR_OR_AZURE_DNS_RE = re.compile(r"^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$")
FQDN_RE = re.compile(r"^(\*\.)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$")
ALLOWED_NETWORK_DESTINATIONS = {"168.63.129.16"}
ALLOWED_NETWORK_PORTS = {"53"}
ALLOWED_NETWORK_PROTOCOLS = {"TCP", "UDP"}


def require(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        errors.append(message)


def validate_protocols(rule_path: str, protocols, errors: list[str]) -> None:
    require(isinstance(protocols, list) and protocols, errors, f"{rule_path}: protocols must be a non-empty list")
    for index, protocol in enumerate(protocols or []):
        item_path = f"{rule_path}.protocols[{index}]"
        require(isinstance(protocol, dict), errors, f"{item_path}: must be an object")
        if not isinstance(protocol, dict):
            continue
        require(protocol.get("type") == "Https", errors, f"{item_path}.type must be Https")
        require(protocol.get("port") == 443, errors, f"{item_path}.port must be 443")


def validate_application_collections(data: dict, errors: list[str], seen_priorities: set[int]) -> set[str]:
    collections = data.get("application_rule_collections")
    require(isinstance(collections, list) and collections, errors, "application_rule_collections must be a non-empty list")

    seen_rule_names: set[str] = set()
    fqdn_coverage: set[str] = set()

    for collection_index, collection in enumerate(collections or []):
        path = f"application_rule_collections[{collection_index}]"
        require(isinstance(collection, dict), errors, f"{path}: must be an object")
        if not isinstance(collection, dict):
            continue

        name = collection.get("name")
        priority = collection.get("priority")
        require(isinstance(name, str) and NAME_RE.match(name) is not None, errors, f"{path}.name must be a kebab-case name")
        require(isinstance(priority, int) and 100 <= priority <= 65000, errors, f"{path}.priority must be 100-65000")
        require(priority not in seen_priorities, errors, f"{path}.priority {priority} is duplicated")
        seen_priorities.add(priority)
        require(collection.get("action") == "Allow", errors, f"{path}.action must be Allow")

        rules = collection.get("rules")
        require(isinstance(rules, list) and rules, errors, f"{path}.rules must be a non-empty list")
        for rule_index, rule in enumerate(rules or []):
            rule_path = f"{path}.rules[{rule_index}]"
            require(isinstance(rule, dict), errors, f"{rule_path}: must be an object")
            if not isinstance(rule, dict):
                continue

            rule_name = rule.get("name")
            require(isinstance(rule_name, str) and NAME_RE.match(rule_name) is not None, errors, f"{rule_path}.name must be kebab-case")
            require(rule_name not in seen_rule_names, errors, f"{rule_path}.name {rule_name!r} is duplicated")
            seen_rule_names.add(str(rule_name))

            fqdns = rule.get("destination_fqdns")
            require(isinstance(fqdns, list) and fqdns, errors, f"{rule_path}.destination_fqdns must be non-empty")
            for fqdn in fqdns or []:
                require(isinstance(fqdn, str) and fqdn != "*" and FQDN_RE.match(fqdn) is not None, errors, f"{rule_path}: invalid destination FQDN {fqdn!r}")
                fqdn_coverage.add(str(fqdn).lower())

            validate_protocols(rule_path, rule.get("protocols"), errors)

    return fqdn_coverage


def validate_network_collections(data: dict, errors: list[str], seen_priorities: set[int]) -> None:
    collections = data.get("network_rule_collections", [])
    require(isinstance(collections, list), errors, "network_rule_collections must be a list when present")

    for collection_index, collection in enumerate(collections or []):
        path = f"network_rule_collections[{collection_index}]"
        require(isinstance(collection, dict), errors, f"{path}: must be an object")
        if not isinstance(collection, dict):
            continue
        priority = collection.get("priority")
        require(isinstance(priority, int) and 100 <= priority <= 65000, errors, f"{path}.priority must be 100-65000")
        require(priority not in seen_priorities, errors, f"{path}.priority {priority} is duplicated")
        seen_priorities.add(priority)
        require(collection.get("action") == "Allow", errors, f"{path}.action must be Allow")
        rules = collection.get("rules")
        require(isinstance(rules, list) and rules, errors, f"{path}.rules must be non-empty")
        for rule_index, rule in enumerate(rules or []):
            rule_path = f"{path}.rules[{rule_index}]"
            require(isinstance(rule, dict), errors, f"{rule_path}: must be an object")
            if not isinstance(rule, dict):
                continue
            require(isinstance(rule.get("name"), str) and NAME_RE.match(rule["name"]) is not None, errors, f"{rule_path}.name must be kebab-case")
            destinations = set(rule.get("destination_addresses") or [])
            ports = set(rule.get("destination_ports") or [])
            protocols = set(rule.get("protocols") or [])
            require(destinations and destinations <= ALLOWED_NETWORK_DESTINATIONS, errors, f"{rule_path}.destination_addresses may only contain Azure DNS resolver 168.63.129.16")
            require(ports and ports <= ALLOWED_NETWORK_PORTS, errors, f"{rule_path}.destination_ports may only contain 53")
            require(protocols and protocols <= ALLOWED_NETWORK_PROTOCOLS, errors, f"{rule_path}.protocols may only contain TCP and UDP")


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else Path("policies/azure/firewall/allowlist.json")
    errors: list[str] = []

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read firewall allowlist {path}: {exc}", file=sys.stderr)
        return 1

    require(isinstance(data.get("version"), str) and data.get("version"), errors, "version is required")
    seen_priorities: set[int] = set()
    fqdn_coverage = validate_application_collections(data, errors, seen_priorities)
    validate_network_collections(data, errors, seen_priorities)

    missing = REQUIRED_FQDNS - fqdn_coverage
    if missing:
        errors.append(f"required Stage 03 FQDNs missing: {', '.join(sorted(missing))}")

    if errors:
        print("Firewall allowlist checks FAILED:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"Firewall allowlist checks passed ({len(fqdn_coverage)} FQDNs covered).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
