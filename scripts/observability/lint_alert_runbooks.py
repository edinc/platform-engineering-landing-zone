#!/usr/bin/env python3
"""Ensure Prometheus alert rules include runbook_url annotations."""

from pathlib import Path
import re
import sys


ALERT_RE = re.compile(r"^\s*-\s*alert:\s*(?P<name>[A-Za-z0-9_:.-]+)\s*$")
TF_ALERT_RE = re.compile(r'^\s*alert\s+=\s+"(?P<name>[^"]+)"\s*$')


def lint_file(path: Path) -> list[str]:
    if path.suffix == ".tf":
        return lint_terraform_file(path)

    failures: list[str] = []
    current_alert: str | None = None
    current_line = 0
    has_runbook = False

    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        match = ALERT_RE.match(line)
        if match:
            if current_alert and not has_runbook:
                failures.append(f"{path}:{current_line}: alert {current_alert} missing runbook_url")
            current_alert = match.group("name")
            current_line = line_number
            has_runbook = False
            continue
        if current_alert and "runbook_url:" in line:
            has_runbook = True

    if current_alert and not has_runbook:
        failures.append(f"{path}:{current_line}: alert {current_alert} missing runbook_url")
    return failures


def lint_terraform_file(path: Path) -> list[str]:
    failures: list[str] = []
    current_alert: str | None = None
    current_line = 0
    has_runbook = False

    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        match = TF_ALERT_RE.match(line)
        if match:
            if current_alert and not has_runbook:
                failures.append(f"{path}:{current_line}: alert {current_alert} missing runbook_url")
            current_alert = match.group("name")
            current_line = line_number
            has_runbook = False
            continue
        if current_alert and "runbook_url" in line:
            has_runbook = True

    if current_alert and not has_runbook:
        failures.append(f"{path}:{current_line}: alert {current_alert} missing runbook_url")
    return failures


def main() -> int:
    files = [Path(arg) for arg in sys.argv[1:] if Path(arg).is_file()]
    failures: list[str] = []
    for path in files:
        failures.extend(lint_file(path))

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"Alert runbook lint passed for {len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
