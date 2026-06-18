# Runbook: Existing subscription onboarding

This runbook onboards an **existing Azure subscription** into the platform
baseline without taking ownership of the tenant-wide Azure Landing Zone. It is
the dry-run procedure to validate the
subscription's inherited ALZ posture, diagnostics, Defender state, and mandatory
tag inventory before applying the subscription-baseline Terraform stack.

Related decisions: [ADR-0011](../adr/0011-compliance-baseline.md) (baseline),
[ADR-0028](../adr/0028-subscription-topology.md) (subscription topology),
[ADR-0027](../adr/0027-policy-exception.md) (exceptions).

## Overview

```
discover (read-only)  ->  confirm ALZ placement  ->  apply sub baseline  ->  drain tag/policy findings
readiness-discovery      external ALZ owner         Defender/diag/budget     tag or exempt (ADR-0027)
```

| Phase | Writes? | What happens |
| --- | --- | --- |
| 1. Discover | **No** | Inventory policy assignments, Defender, diagnostics, and untagged resources |
| 2. Confirm ALZ placement | External | ALZ owner confirms the subscription is in the expected management group |
| 3. Apply subscription baseline | Yes | Configure Defender, Activity Log diagnostics, budget, and optional cost export |
| 4. Drain inventory | Yes | Tag or exempt every non-compliant resource through the ALZ exception process |

## Prerequisites

- **Reader** on the target subscription is enough for Phase 1 discovery. Later
  phases need the deploy identity permissions documented in the subscription
  baseline README.
- `az` CLI (logged in: `az login --tenant <tenant-guid>`), `jq`, and the repo
  toolchain (`mise install`).
- A **non-empty test subscription** already created by the external ALZ/vending
  process.
- Existing shared-service IDs when enabled:
  - central Log Analytics workspace resource ID;
  - existing cost-export storage container resource ID.

## 1. Discover (read-only — makes no changes)

Run the discovery script. It only performs `az ... list/show` calls.

```bash
# Inspect the current subscription:
scripts/subscription/readiness-discovery.sh \
  -p "06f19060-9e68-4070-92ca-f15cc126059e" \
  -p "<mandatory-tag-assignment-name-or-policy-id>"

# Or target a specific subscription and save JSON snapshots:
scripts/subscription/readiness-discovery.sh \
  -s <test-subscription-id> \
  -p "06f19060-9e68-4070-92ca-f15cc126059e" \
  -p "<mandatory-tag-assignment-name-or-policy-id>" \
  -o ./.discovery
```

The `-p` values are required inherited policy expectations. Use the actual
assignment names, assignment IDs, display names, or policy definition IDs from
your ALZ. The CIS Foundations v2 built-in initiative ID is shown above as an
example. If the subscription is intentionally onboarded before inherited policy
is visible, use `-x` only when the onboarding PR links the approved ALZ
exception/change ticket.

> The `-o` snapshots contain tenant-specific inventory (subscription IDs are
> embedded in resource ARM IDs). `./.discovery` is gitignored, and the script
> **refuses** to write into any in-repo path that is not gitignored, so a routine
> `git add` cannot commit them. Treat the snapshots as ephemeral; delete them when
> done, or use a path outside the repo.

Review the sections it prints:

1. **Signed-in context** — confirm tenant and subscription are the target.
2. **Policy assignments visible at subscription scope** — confirm the expected
   inherited ALZ/CIS/tag/private-link assignments are present.
3. **Defender pricing** — record current tiers before the subscription baseline changes them.
4. **Resource providers** — confirm `Microsoft.Security` is registered before
   applying because the Terraform provider will not auto-register it. The script
   also reports optional providers for diagnostics (`Microsoft.Insights`), budget
   (`Microsoft.Consumption`), and cost exports (`Microsoft.CostManagement`) so
   you can register them before enabling those features.
5. **Activity Log diagnostics** — confirm whether a subscription diagnostic
   setting already routes logs to the central workspace.
6. **Resource groups and resources missing mandatory tags** — this is the
   inherited tag-policy blast radius. It must be tagged or exempted before
   tightening enforcement.

## 2. Confirm ALZ placement

The subscription baseline does **not** move subscriptions between management groups. If discovery
or the ALZ owner's inventory shows the subscription is under the wrong MG, stop
and have the ALZ/vending owner correct placement first.

Record the expected placement and inherited policy set in the onboarding PR or
change ticket. This keeps the subscription-baseline stack from becoming an
implicit substitute for ALZ governance.

## 3. Apply the subscription baseline

Copy the example inputs and provide only the subscription-scoped settings this
repo owns:

```hcl
# infrastructure/terraform/subscription-baseline/terraform.tfvars
tenant_id       = "<tenant-id>"
subscription_id = "<test-subscription-id>"

log_analytics_workspace_id      = "<existing-central-workspace-id>"
enable_activity_log_diagnostics = true
approved_log_analytics_workspace_subscription_ids = [
  "<monitoring-subscription-id>"
]

defender_tiers = {
  virtual_machines = "Standard"
  containers       = "Standard"
  key_vaults       = "Standard"
  storage_accounts = "Standard"
  sql_servers      = "Standard"
  open_source_dbs  = "Standard"
  resource_manager = "Standard"
  apis             = "Standard"
}

# Optional:
# monthly_budget_amount = 500
# budget_start_date     = "2026-07-01T00:00:00Z"
# budget_contact_emails = ["platform-engineering@example.com"]
# cost_export_storage_container_id = "<existing-container-id>"
# approved_cost_export_storage_subscription_ids = ["<cost-storage-subscription-id>"]
# cost_export_recurrence_from = "2026-07-01T00:00:00Z"
# cost_export_recurrence_to   = "2030-07-01T00:00:00Z"
```

Then run the normal Terraform plan/apply path for the
`infrastructure/terraform/subscription-baseline/` stack. The apply configures
only subscription-scoped resources: Defender pricing, Activity Log diagnostics,
optional budget, and optional cost export.

For brownfield subscriptions where Defender pricing plans already exist, import
the existing pricing resources into state before the first apply:

```bash
terraform -chdir=infrastructure/terraform/subscription-baseline init -backend-config=backend.hcl
scripts/subscription/import-defender-pricing.sh \
  --subscription-id <test-subscription-id>
```

The helper is idempotent and imports the Defender plan resource types managed by
the subscription baseline stack (`VirtualMachines`, `Containers`, `KeyVaults`,
`StorageAccounts`, `SqlServers`, `OpenSourceRelationalDatabases`, `Arm`, and
`Api`).

If the follow-up plan shows it would remove or replace existing Defender
subplans or extensions, preserve the brownfield settings explicitly:

```hcl
defender_plan_subplans = {
  Arm             = "PerApiCall"
  KeyVaults       = "PerTransaction"
  StorageAccounts = "DefenderForStorageV2"
  VirtualMachines = "P2"
}

defender_plan_extensions = {
  VirtualMachines = [
    {
      name = "AgentlessVmScanning"
      additional_extension_properties = {
        ExclusionTags = "[]"
      }
    }
  ]
  StorageAccounts = [
    {
      name = "OnUploadMalwareScanning"
      additional_extension_properties = {
        CapGBPerMonthPerStorageAccount = "5000"
      }
    },
    { name = "SensitiveDataDiscovery" }
  ]
}
```

Do not apply a plan that removes inherited ALZ/Defender extensions unless a
security owner has approved the downgrade.

## 4. Drain the non-compliant inventory

For every resource the discovery script flagged:

- **Tag it** with the eight mandatory tags (`env`, `owner`, `costCenter`,
  `product`, `dataClassification`, `confidentiality`, `managedBy`, `repo`), or
- **Exempt it** with a time-bound waiver via the
  [policy-exception runbook](policy-exception.md) (ADR-0027).

Re-run discovery until the non-compliant count is zero or every remaining
resource has an active exemption:

```bash
scripts/subscription/readiness-discovery.sh \
  -s <test-subscription-id> \
  -p "06f19060-9e68-4070-92ca-f15cc126059e" \
  -p "<mandatory-tag-assignment-name-or-policy-id>" \
  -o ./.discovery
```

## Rollback

- Disable Activity Log diagnostics by setting
  `enable_activity_log_diagnostics = false` and applying.
- Remove the budget by setting `monthly_budget_amount = null` and applying.
- Remove the cost export by emptying `cost_export_storage_container_id` and
  applying.
- Defender tiers can be set back to `Free` for the affected plans.

Rollback does not move the subscription or alter inherited ALZ policy
assignments; those remain with the external ALZ owner.

## References

- [`scripts/subscription/readiness-discovery.sh`](../../scripts/subscription/readiness-discovery.sh)
- [`infrastructure/terraform/subscription-baseline/`](../../infrastructure/terraform/subscription-baseline/)
- [ADR-0011: Compliance baseline](../adr/0011-compliance-baseline.md)
- [ADR-0027: Policy exception workflow](../adr/0027-policy-exception.md)
- [ADR-0028: Subscription topology](../adr/0028-subscription-topology.md)
- [Runbook: Policy exception](policy-exception.md)
