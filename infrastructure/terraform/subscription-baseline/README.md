# Subscription baseline (Stage 02)

Subscription-scoped baseline for environments where an Azure Landing Zone
already exists. This stack does **not** create management groups, move
subscriptions, or own tenant-wide policy assignments. It hardens one existing
subscription at a time and consumes shared ALZ services as inputs.

Related decisions: [ADR-0011](../../../docs/adr/0011-compliance-baseline.md)
(baseline), [ADR-0026](../../../docs/adr/0026-avm-modules.md) (composition
choice), [ADR-0027](../../../docs/adr/0027-policy-exception.md) (exceptions),
[ADR-0028](../../../docs/adr/0028-subscription-topology.md) (topology), and
[ADR-0014](../../../docs/adr/0014-terraform-state.md) (state).

## What this stack owns

| Capability | Resource | Notes |
|------------|----------|-------|
| Defender for Cloud | `azurerm_security_center_subscription_pricing` | Per-plan tier on the target subscription. Tiers are required explicit inputs so onboarding cannot accidentally downgrade an existing `Standard` plan to `Free`. |
| Activity Log diagnostics | `azurerm_monitor_diagnostic_setting` | Optional, routes subscription Activity Log categories to an existing Log Analytics workspace. |
| Monthly budget | `azurerm_consumption_budget_subscription` | Optional, one budget for the target subscription. |
| Cost export | `azurerm_subscription_cost_management_export` | Optional, writes daily actual-cost exports to an existing storage container owned by the platform/ALZ. |

## What this stack deliberately does not own

- Management-group hierarchy.
- Subscription placement/moves between management groups.
- Custom policy definitions or tenant/MG-scoped assignments.
- Central Log Analytics workspace or Cost Management storage account.
- Connectivity, Private Endpoints, hub networking, and DNS.

Those are assumed to be supplied by the existing ALZ/platform foundation. The
policy initiative JSON under [`policies/azure/initiatives/`](../../../policies/azure/initiatives/)
remains as a reference/optional policy pack for ALZ administrators and is still
validated in CI, but this Terraform stack no longer deploys it.

## Prerequisites

- Stage 01 complete: Terraform state account, `subscription-baseline` container,
  and OIDC deploy identity.
- The target subscription already exists and is placed in the appropriate ALZ
  management group by the tenant/platform team.
- The deploy identity has permissions on the target subscription to configure:
  Defender pricing, subscription Activity Log diagnostic settings, budgets, and
  cost exports.
- Existing shared-service inputs, when enabled:
  - `log_analytics_workspace_id` for Activity Log diagnostics.
  - `cost_export_storage_container_id` for Cost Management exports.
- Resource providers on the target subscription:
  - required for the minimal baseline: `Microsoft.Security`;
  - required only when optional features are enabled:
    `Microsoft.Insights` (Activity Log diagnostics), `Microsoft.Consumption`
    (budgets), and `Microsoft.CostManagement` (cost exports).

## State backend

State lives in the Stage 01 account, container `subscription-baseline`, with a
unique key per onboarded subscription/environment, for example
`subscriptions/<subscription-id>/subscription-baseline.tfstate`. Copy
`backend.hcl.example` to `backend.hcl`, fill `resource_group_name` and
`storage_account_name` from the `_bootstrap` outputs, then:

```bash
terraform init -backend-config=backend.hcl
```

CI validates credential-free with `terraform init -backend=false` (see the
[Makefile](../../../Makefile) and [`ci.yml`](../../../.github/workflows/ci.yml)).

## Key inputs

See [`variables.tf`](variables.tf) and
[`terraform.tfvars.example`](terraform.tfvars.example) for the full set.

| Input | Required? | Purpose |
|-------|-----------|---------|
| `tenant_id` | yes | Entra tenant for the target subscription. |
| `subscription_id` | yes | Existing subscription to baseline. |
| `log_analytics_workspace_id` | only if diagnostics enabled | Existing workspace for subscription Activity Logs. |
| `approved_log_analytics_workspace_subscription_ids` | only if diagnostics enabled | Approved subscription IDs that may host the diagnostics workspace. |
| `defender_tiers` | yes | Explicit per-resource Defender plan tiers; use `Free` only for demo or approved exceptions. |
| `monthly_budget_amount` | no | Enables one monthly subscription budget. |
| `cost_export_storage_container_id` | no | Enables daily Cost Management export to an existing container. |
| `approved_cost_export_storage_subscription_ids` | only if cost export enabled | Approved subscription IDs that may host cost-export storage. |

Activity Log diagnostics are opt-in (`enable_activity_log_diagnostics = true`)
and require `log_analytics_workspace_id` plus an approved workspace-hosting
subscription ID. Cost exports likewise require the destination storage
subscription to be explicitly approved. These guards prevent accidentally routing
activity logs or billing data to an unapproved destination.

Budget and cost-export schedule dates intentionally have no future-dated
defaults. Set them explicitly when enabling those optional features so applies do
not break after a hardcoded date passes.

## Validation

```bash
make lint validate            # fmt + tflint + checkov + terraform validate (-backend=false)
make policy-test-azure        # validates the optional/reference Azure Policy pack
make policy-test-rego         # mandatory-tag Rego (conftest)
```

## Acceptance-criteria mapping

| # | Criterion | Where |
|---|-----------|-------|
| 1 | Existing subscription can be targeted without MG creation/moves | `providers.tf`, `variables.tf` |
| 2 | Existing ALZ policy baseline is assumed and documented | ADR-0011, policy README, readiness runbook |
| 3 | Mandatory tag taxonomy remains validated in CI and available to ALZ admins | `tag-baseline.json`, `policy-test-azure`, Rego |
| 4 | Defender posture configured for the target subscription | `defender.tf` |
| 5 | Cost exports can land in an existing ALZ storage container | `cost-exports.tf` |
| 6 | Representative demo plan remains policy-compliant | [`../envs/demo/`](../envs/demo/) + Rego |
| 7 | Subscription readiness discovery is documented and scriptable | [readiness runbook](../../../docs/runbooks/subscription-onboarding.md) + `scripts/subscription/readiness-discovery.sh` |
| 8 | AKS policy pack still excludes Gatekeeper add-on | `aks-baseline.json`, `policy-test-azure` |
