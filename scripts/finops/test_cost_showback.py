#!/usr/bin/env python3
"""Small regression tests for Stage 08 cost showback allocation."""

from datetime import datetime, timezone
import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "infrastructure/terraform/_modules/cost-allocator/function_app/shared_code/cost_showback.py"
spec = importlib.util.spec_from_file_location("cost_showback", MODULE)
cost_showback = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(cost_showback)


def test_allocates_tagged_and_untagged_costs() -> None:
    rows = [
        {
            "CostInBillingCurrency": "12.34567",
            "Tags": '{"costCenter":"cc-123","team":"payments","product":"checkout"}',
        },
        {
            "CostInBillingCurrency": "2.00",
            "Tags": "costCenter=cc-123;team==cmd|calc;product=checkout",
        },
        {
            "CostInBillingCurrency": "4",
            "Tags": '{"team":"missing-cost-center"}',
        },
    ]

    allocations = cost_showback.allocate_cost_rows(rows)
    assert allocations == [
        {
            "costCenter": "cc-123",
            "team": "=cmd|calc",
            "product": "checkout",
            "cost": "2.0000",
        },
        {
            "costCenter": "cc-123",
            "team": "payments",
            "product": "checkout",
            "cost": "12.3457",
        },
        {
            "costCenter": "platform-overhead",
            "team": "missing-cost-center",
            "product": "shared-platform",
            "cost": "4.0000",
        },
    ]

    csv_output = cost_showback.write_showback_csv(
        allocations,
        datetime(2026, 6, 12, tzinfo=timezone.utc),
    )
    assert "generatedAt,costCenter,team,product,cost" in csv_output
    assert "cc-123,'=cmd|calc,checkout,2.0000" in csv_output
    assert "platform-overhead,missing-cost-center,shared-platform,4.0000" in csv_output


def test_function_package_is_deterministic_and_complete() -> None:
    import hashlib
    import subprocess
    import tempfile
    import zipfile

    script = ROOT / "scripts/cost-allocator/package-function.sh"
    assert script.exists(), "package-function.sh must exist"

    def build(target: Path) -> bytes:
        subprocess.run(["bash", str(script), str(target)], check=True, cwd=ROOT)
        return target.read_bytes()

    with tempfile.TemporaryDirectory() as tmp:
        first = build(Path(tmp) / "a.zip")
        second = build(Path(tmp) / "b.zip")
        assert hashlib.sha256(first).hexdigest() == hashlib.sha256(second).hexdigest(), (
            "Function package must be byte-reproducible so Terraform does not detect spurious changes"
        )
        with zipfile.ZipFile(Path(tmp) / "a.zip") as archive:
            names = set(archive.namelist())
    expected = {
        "function_app.py",
        "host.json",
        "requirements.txt",
        "shared_code/cost_showback.py",
    }
    missing = expected - names
    assert not missing, f"Function package is missing required files: {sorted(missing)}"
    assert not any(name.endswith((".pyc", ".pyo")) for name in names), "Function package must not include compiled artifacts"


if __name__ == "__main__":
    test_allocates_tagged_and_untagged_costs()
    test_function_package_is_deterministic_and_complete()
    print("Cost showback allocation and packaging tests passed.")
