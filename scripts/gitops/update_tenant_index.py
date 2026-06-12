#!/usr/bin/env python3
"""Add tenant resources to an environment overlay kustomization."""

from pathlib import Path
import sys


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: update_tenant_index.py <kustomization.yaml> <resource> [<resource> ...]")

    path = Path(sys.argv[1])
    resources = sys.argv[2:]
    text = path.read_text()
    changed = False

    for resource in resources:
        item = f"  - {resource}\n"
        if item in text:
            continue
        if "resources: []" in text:
            text = text.replace("resources: []", f"resources:\n{item}")
        elif "resources:\n" in text:
            text = text.rstrip() + f"\n{item}"
        else:
            text = text.rstrip() + f"\nresources:\n{item}"
        changed = True

    if changed:
        path.write_text(text)


if __name__ == "__main__":
    main()
