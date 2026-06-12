import csv
import io
import json
from collections import defaultdict
from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Iterable


REQUIRED_TAGS = ("costCenter", "team", "product")
UNTAGGED = {
    "costCenter": "platform-overhead",
    "team": "platform-overhead",
    "product": "shared-platform",
}


def parse_tags(raw_tags: str | None) -> dict[str, str]:
    if not raw_tags:
        return {}
    raw_tags = raw_tags.strip()
    if not raw_tags:
        return {}
    try:
        parsed = json.loads(raw_tags)
        if isinstance(parsed, dict):
            return {str(key): str(value) for key, value in parsed.items() if value is not None}
    except json.JSONDecodeError:
        pass

    tags: dict[str, str] = {}
    for part in raw_tags.replace(";", ",").split(","):
        if ":" in part:
            key, value = part.split(":", 1)
        elif "=" in part:
            key, value = part.split("=", 1)
        else:
            continue
        key = key.strip().strip('"')
        value = value.strip().strip('"')
        if key and value:
            tags[key] = value
    return tags


def row_cost(row: dict[str, str]) -> Decimal:
    for field in ("CostInBillingCurrency", "PreTaxCost", "Cost", "cost"):
        value = row.get(field)
        if value not in (None, ""):
            try:
                return Decimal(str(value))
            except InvalidOperation as exc:
                raise ValueError(f"Invalid cost value for {field}: {value}") from exc
    return Decimal("0")


def allocation_key(row: dict[str, str]) -> tuple[str, str, str]:
    tags = parse_tags(row.get("Tags") or row.get("tags"))
    normalized = {field: tags.get(field) or row.get(field) or UNTAGGED[field] for field in REQUIRED_TAGS}
    return tuple(normalized[field] for field in REQUIRED_TAGS)


def allocate_cost_rows(rows: Iterable[dict[str, str]]) -> list[dict[str, str]]:
    totals: dict[tuple[str, str, str], Decimal] = defaultdict(lambda: Decimal("0"))
    for row in rows:
        totals[allocation_key(row)] += row_cost(row)

    allocations = []
    for (cost_center, team, product), total in sorted(totals.items()):
        allocations.append(
            {
                "costCenter": cost_center,
                "team": team,
                "product": product,
                "cost": f"{total.quantize(Decimal('0.0001'))}",
            }
        )
    return allocations


def write_showback_csv(allocations: list[dict[str, str]], generated_at: datetime) -> str:
    output = io.StringIO()
    fieldnames = ["generatedAt", "costCenter", "team", "product", "cost"]
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    for allocation in allocations:
        writer.writerow(
            {
                "generatedAt": generated_at.isoformat(),
                "costCenter": neutralize_csv_formula(allocation["costCenter"]),
                "team": neutralize_csv_formula(allocation["team"]),
                "product": neutralize_csv_formula(allocation["product"]),
                "cost": allocation["cost"],
            }
        )
    return output.getvalue()


def neutralize_csv_formula(value: str) -> str:
    stripped = value.lstrip(" \t\r\n")
    if stripped.startswith(("=", "+", "-", "@")):
        return f"'{value}"
    return value
