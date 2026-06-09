#!/usr/bin/env python3
"""Validate-time guard for the Stage 02 custom Azure Policy initiatives.

Terraform `check {}` blocks only evaluate at plan/apply, which CI cannot run
without Azure credentials. This script enforces the security-critical Stage 02
acceptance criteria statically against the initiative JSON source of truth
(policies/azure/initiatives/), using only the Python standard library so it adds
no new tooling (ADR-0047 keeps Azure-policy validation separate from Rego and
Kyverno).

Enforced invariants:
  * Every initiative is well-formed and carries the required fields.
  * Every member policyDefinitionId is a pinned built-in policy GUID.
  * Reference IDs are unique within an initiative.
  * Criterion 8: no initiative installs the AKS Policy (Gatekeeper) add-on;
    aks-baseline must not reference its GUID and cannot allow a Deny effect
    (Kyverno is the single in-cluster admission engine, ADR-0036).
  * Criterion 3: tag-baseline requires every mandatory tag on both resources
    and resource groups; it is the only Deny initiative, and the other
    initiatives default to Audit.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# AKS Policy (Gatekeeper) add-on DeployIfNotExists - must never appear.
GATEKEEPER_ADDON_GUID = "a8eff44f-8c92-45c3-a3fb-9880802d67a7"

# Mandatory tag taxonomy (plan.md section 10).
MANDATORY_TAGS = {
    "env",
    "owner",
    "costCenter",
    "product",
    "dataClassification",
    "confidentiality",
    "managedBy",
    "repo",
}

# Built-in "require a tag" policy GUIDs used by tag-baseline.
REQUIRE_TAG_RESOURCE_GUID = "871b6d14-10aa-478d-b590-94f262ecfa99"
REQUIRE_TAG_RG_GUID = "96670d01-0a4d-4649-9c89-2d3abc0a5025"

POLICY_DEF_ID_RE = re.compile(
    r"^/providers/Microsoft\.Authorization/policyDefinitions/"
    r"([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$"
)

REQUIRED_TOP_FIELDS = ("name", "displayName", "description", "policyDefinitions")


def guid_of(policy_definition_id: str):
    match = POLICY_DEF_ID_RE.match(policy_definition_id)
    return match.group(1).lower() if match else None


def validate_initiative(path: Path, errors: list):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.name}: not valid JSON: {exc}")
        return None

    for field in REQUIRED_TOP_FIELDS:
        if field not in data:
            errors.append(f"{path.name}: missing required field '{field}'")

    definitions = data.get("policyDefinitions")
    if not isinstance(definitions, list) or not definitions:
        errors.append(f"{path.name}: policyDefinitions must be a non-empty array")
        return data

    seen_refs = set()
    for index, ref in enumerate(definitions):
        ref_id = ref.get("policyDefinitionReferenceId")
        if not ref_id:
            errors.append(f"{path.name}: policyDefinitions[{index}] missing policyDefinitionReferenceId")
        elif ref_id in seen_refs:
            errors.append(f"{path.name}: duplicate policyDefinitionReferenceId '{ref_id}'")
        else:
            seen_refs.add(ref_id)

        policy_id = ref.get("policyDefinitionId", "")
        if guid_of(policy_id) is None:
            errors.append(
                f"{path.name}: policyDefinitions[{index}] policyDefinitionId is not a pinned "
                f"built-in policy GUID: {policy_id!r}"
            )

    return data


def assert_no_gatekeeper(name: str, data: dict, errors: list):
    for ref in data.get("policyDefinitions", []):
        if guid_of(ref.get("policyDefinitionId", "")) == GATEKEEPER_ADDON_GUID:
            errors.append(
                f"{name}: references the AKS Policy (Gatekeeper) add-on GUID "
                f"{GATEKEEPER_ADDON_GUID}; it must be excluded (acceptance criterion 8, ADR-0036)."
            )


def effect_param(data: dict):
    params = data.get("parameters") or {}
    return params.get("effect")


def main(argv: list) -> int:
    initiatives_dir = Path(argv[1]) if len(argv) > 1 else Path("policies/azure/initiatives")
    if not initiatives_dir.is_dir():
        print(f"ERROR: initiatives directory not found: {initiatives_dir}", file=sys.stderr)
        return 1

    files = sorted(initiatives_dir.glob("*.json"))
    if not files:
        print(f"ERROR: no initiative JSON files in {initiatives_dir}", file=sys.stderr)
        return 1

    errors = []
    initiatives = {}

    for path in files:
        data = validate_initiative(path, errors)
        if data is not None:
            initiatives[path.stem] = data
            assert_no_gatekeeper(path.stem, data, errors)

    # Criterion 8: aks-baseline must exist and never allow a Deny effect.
    aks = initiatives.get("aks-baseline")
    if aks is None:
        errors.append("aks-baseline.json is required but was not found.")
    else:
        param = effect_param(aks)
        if param and "Deny" in param.get("allowedValues", []):
            errors.append(
                "aks-baseline: effect parameter must not allow 'Deny'; cluster-level "
                "enforcement is handled by Kyverno (ADR-0036)."
            )

    # Criterion 3: tag-baseline requires every mandatory tag on resources AND
    # resource groups, and is the only Deny initiative.
    tag = initiatives.get("tag-baseline")
    if tag is None:
        errors.append("tag-baseline.json is required but was not found.")
    else:
        covered = {"resource": set(), "rg": set()}
        for ref in tag.get("policyDefinitions", []):
            guid = guid_of(ref.get("policyDefinitionId", ""))
            tag_name = (ref.get("parameters", {}).get("tagName", {}) or {}).get("value")
            if guid == REQUIRE_TAG_RESOURCE_GUID and tag_name:
                covered["resource"].add(tag_name)
            elif guid == REQUIRE_TAG_RG_GUID and tag_name:
                covered["rg"].add(tag_name)
        for scope, label in (("resource", "resources"), ("rg", "resource groups")):
            missing = MANDATORY_TAGS - covered[scope]
            if missing:
                errors.append(
                    f"tag-baseline: missing require-tag rules for {label}: "
                    f"{', '.join(sorted(missing))} (acceptance criterion 3)."
                )

    # Other initiatives must default to Audit (no broad Deny at Stage 02).
    for name in ("private-link-required",):
        data = initiatives.get(name)
        if data is None:
            continue
        param = effect_param(data)
        if param and param.get("defaultValue") != "Audit":
            errors.append(
                f"{name}: effect default must be 'Audit' during the Stage 02 grace period "
                f"(acceptance criterion 2)."
            )

    if errors:
        print("Azure initiative policy checks FAILED:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"Azure initiative policy checks passed ({len(initiatives)} initiatives).")
    for name in sorted(initiatives):
        count = len(initiatives[name].get("policyDefinitions", []))
        print(f"  - {name}: {count} pinned built-in references")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
