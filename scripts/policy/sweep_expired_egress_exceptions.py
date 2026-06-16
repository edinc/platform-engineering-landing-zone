#!/usr/bin/env python3
"""Remove expired Stage 10 egress exception artifacts from the repo."""

from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PATCH_DIR = ROOT / "policies/azure/firewall/exception-patches"
OVERLAYS_DIR = ROOT / "platform-gitops/clusters/overlays"
ALLOWLIST = ROOT / "policies/azure/firewall/allowlist.json"
SUMMARY = ROOT / "decommission/expired-egress-exceptions.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def policy_dir(environment: str) -> Path:
    return OVERLAYS_DIR / environment / "network/egress-exceptions"


def remove_kustomization_entries(environment: str, filenames: set[str]) -> None:
    kustomization = policy_dir(environment) / "kustomization.yaml"
    if not kustomization.exists() or not filenames:
        return
    lines = kustomization.read_text(encoding="utf-8").splitlines()
    kept = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("- ") and stripped[2:] in filenames:
            continue
        kept.append(line)
    kustomization.write_text("\n".join(kept).rstrip() + "\n", encoding="utf-8")


def remove_allowlist_collections(collection_names: set[str]) -> None:
    if not ALLOWLIST.exists() or not collection_names:
        return
    allowlist = load_json(ALLOWLIST)
    collections = allowlist.get("application_rule_collections", [])
    allowlist["application_rule_collections"] = [
        collection for collection in collections if collection.get("name") not in collection_names
    ]
    write_json(ALLOWLIST, allowlist)


def main() -> int:
    today = date.today()
    expired: list[dict[str, str]] = []
    collection_names: set[str] = set()
    policy_filenames_by_environment: dict[str, set[str]] = {}

    for patch_path in sorted(PATCH_DIR.glob("*.json")) if PATCH_DIR.exists() else []:
        patch = load_json(patch_path)
        collection = patch.get("collection", {})
        metadata = collection.get("metadata", {})
        try:
            expires_on = date.fromisoformat(str(metadata.get("expiresOn")))
        except ValueError:
            continue
        if expires_on >= today:
            continue

        collection_name = str(collection.get("name", ""))
        policy_filename = f"{patch_path.stem}.yaml"
        namespace = str(metadata.get("namespace", ""))
        environment = namespace.rsplit("-", 1)[-1]
        if environment not in {"demo", "nonprod", "prod"}:
            continue
        expired.append(
            {
                "patch": str(patch_path.relative_to(ROOT)),
                "policy": str((policy_dir(environment) / policy_filename).relative_to(ROOT)),
                "collection": collection_name,
                "expiresOn": expires_on.isoformat(),
                "team": str(metadata.get("team", "")),
                "namespace": namespace,
            }
        )
        if collection_name:
            collection_names.add(collection_name)
        policy_filenames_by_environment.setdefault(environment, set()).add(policy_filename)
        patch_path.unlink()
        policy_path = policy_dir(environment) / policy_filename
        if policy_path.exists():
            policy_path.unlink()

    for environment, policy_filenames in policy_filenames_by_environment.items():
        remove_kustomization_entries(environment, policy_filenames)
    remove_allowlist_collections(collection_names)

    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    write_json(SUMMARY, {"generatedOn": today.isoformat(), "expired": expired})
    print(f"expired_count={len(expired)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
