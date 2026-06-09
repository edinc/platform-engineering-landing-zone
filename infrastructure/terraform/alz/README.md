# ALZ baseline (Stage 02)

Native `azurerm` composition of the Azure Landing Zone baseline: the
management-group hierarchy, the compliance baseline (CIS v2 + custom
initiatives), central Log Analytics, Microsoft Defender for Cloud, budgets, and
Cost Management exports. It is **not** built from `Azure/caf-enterprise-scale` or
`Azure/avm-ptn-alz`; the rationale and the AVM audit are in
[ADR-0026](../../../docs/adr/0026-avm-modules.md).

Related decisions: [ADR-0011](../../../docs/adr/0011-compliance-baseline.md)
(baseline), [ADR-0026](../../../docs/adr/0026-avm-modules.md) (composition
choice), [ADR-0027](../../../docs/adr/0027-policy-exception.md) (exceptions),
[ADR-0028](../../../docs/adr/0028-subscription-topology.md) (topology),
[ADR-0014](../../../docs/adr/0014-terraform-state.md) (state).

## Prerequisites

- Stage 01 complete: Terraform state account + `alz` container, OIDC deploy
  identity, and the deploy identity holding (at least) **Management Group
  Contributor** at the tenant root, plus **Owner** where it must create role
  assignments (Defender, cost-export writer, diagnostics remediation roles).
- The following resource providers registered on the management subscription:
  `Microsoft.Security` (Defender pricing), `Microsoft.CostManagementExports`
  (exports), `Microsoft.PolicyInsights` and `Microsoft.Management` (policy +
  MGs), `Microsoft.OperationalInsights` (Log Analytics), `Microsoft.Storage`.
  The provider does not auto-register them (`resource_provider_registrations =
  "none"`), matching `_bootstrap`.
- The repo toolchain: `mise install` (pinned Terraform), plus `az` + `jq` for
  the brownfield discovery script.

## State backend

State lives in the Stage 01 account, container `alz`, key `alz.tfstate`, with
Entra-ID auth. Copy `backend.hcl.example` to `backend.hcl`, fill
`resource_group_name`/`storage_account_name` from the `_bootstrap` outputs, then:

```bash
terraform init -backend-config=backend.hcl
```

CI validates credential-free with `terraform init -backend=false` (see the
[Makefile](../../../Makefile) and [`ci.yml`](../../../.github/workflows/ci.yml)).

## Management-group hierarchy

```
Tenant Root (root_management_group_id | tenant_id)
└── alz
    ├── platform
    │   ├── management      <- central LA, Defender, cost exports (this stack)
    │   ├── connectivity    <- Stage 03
    │   └── identity        <- later stage
    ├── landingzones
    │   ├── corp            <- internal workloads
    │   └── online          <- external workloads
    ├── sandbox
    └── decommissioned
```

Node names are `${management_group_prefix}${key}`. Parents are created before
children automatically (static `for_each` keys).

> **MG-move blast radius.** Associating a subscription or re-parenting a node
> re-evaluates every inherited policy assignment against the new ancestry. Treat
> any change to the hierarchy or to a subscription association as a
> security-reviewed change — see the
> [brownfield runbook](../../../docs/runbooks/brownfield-onboarding.md).

## Policy inventory

Initiatives are defined as JSON in
[`policies/azure/initiatives/`](../../../policies/azure/initiatives/) (source of
truth) and rendered to `azurerm_policy_set_definition` resources. Effects are
audit-first; the tag `Deny` is the only enforced denial (criteria 2 and 3).

| Assignment | Initiative / definition | Scope (MG) | Effect | Controlled by | Default |
|------------|-------------------------|------------|--------|---------------|---------|
| `cis-foundations-v2` | CIS Azure Foundations Benchmark v2 (built-in) | `alz` | Evaluate-only | `cis_enforce` (enforce) | `false` (DoNotEnforce) |
| `pe-tag-baseline` | `tag-baseline` (custom) | `alz` | **Deny** | `tag_baseline_enforce` (enforce) | `true` (Deny active) |
| `pe-private-link` | `private-link-required` (custom) | `alz` | Audit | `private_link_effect` | `Audit` |
| `pe-aks-baseline` | `aks-baseline` (custom) | `landingzones` | Audit | `aks_effect` | `Audit` |
| `pe-diag-to-la` | operator-supplied DINE | `platform` | DeployIfNotExists | `diagnostics_policy_definition_id` | disabled (empty) |

Notes:

- **CIS** carries a SystemAssigned identity so it can be flipped to enforced
  later without recreation; remediation roles are granted out of band at that
  time (ADR-0011).
- **tag-baseline** built-in members are fixed-`Deny`, so enforcement is governed
  by `enforce` (Default vs DoNotEnforce), not an `effect` parameter.
- **private-link** members for Storage and PostgreSQL honour the initiative
  `effect` parameter (`Audit`/`Deny`/`Disabled`); Key Vault and ACR members are
  fixed-Audit built-ins.
- **aks-baseline** allows only `Audit`/`Disabled` (no `Deny`: the
  managed-identity built-in rejects Deny) and **deliberately excludes** the AKS
  Policy (Gatekeeper) add-on — Kyverno is the single in-cluster engine
  (criterion 8, ADR-0036). Absence is asserted three ways: the JSON omits the
  GUID, a Terraform `check {}` block, and the `make policy-test-azure` guard.
- **diagnostics** stays disabled until an operator supplies a concrete DINE
  policy/initiative ID and its parameter schema; a `check {}` block surfaces the
  unmet state without failing the run.

## Other resources

- **Central Log Analytics** (`log-analytics.tf`) in `platform/management`;
  exported as `log_analytics_workspace_id` for per-stage diagnostics.
- **Defender for Cloud** (`defender.tf`) per-plan pricing on the management
  subscription. Tier is per-profile via `defender_tiers`; demo defaults to Free.
- **Budgets** (`budgets.tf`) — per-subscription budgets, driven by
  `subscription_budgets` and empty by default (brownfield-safe); operators add
  entries per associated subscription.
- **Cost exports** (`cost-exports.tf`) — secure ADLS Gen2 account + container +
  lifecycle + daily `ActualCost` export (criterion 5).

## Variables

See [`variables.tf`](variables.tf) for the full set and
[`terraform.tfvars.example`](terraform.tfvars.example) for a starting point. Key
toggles: `cis_enforce`, `tag_baseline_enforce`, `private_link_effect`,
`aks_effect`, `defender_tiers`, the per-MG `*_subscription_id` association
variables, and `diagnostics_policy_definition_id`.

## Validation

```bash
make lint validate            # fmt + tflint + checkov + terraform validate (-backend=false)
make policy-test-azure        # guards criteria 3 and 8 against the initiative JSON
make policy-test-rego         # mandatory-tag Rego (conftest)
```

## Acceptance-criteria mapping

| # | Criterion | Where |
|---|-----------|-------|
| 1 | MG hierarchy + optional subscription associations | `management-groups.tf`, `locals.tf` |
| 2 | CIS + ALZ initiatives, Audit/DINE except tag Deny | `assignments.tf`, `initiatives.tf` |
| 3 | tag Deny on missing mandatory tags (only Deny) | `tag-baseline.json`, `pe-tag-baseline` |
| 4 | Defender plans on management -> Secure Score | `defender.tf` |
| 5 | Cost exports to ADLS Gen2, daily | `cost-exports.tf` |
| 6 | Representative demo plan is policy-compliant | [`../envs/demo/`](../envs/demo/) + Rego |
| 7 | Brownfield dry-run validated | [brownfield runbook](../../../docs/runbooks/brownfield-onboarding.md) + `scripts/alz/brownfield-discovery.sh` |
| 8 | aks-baseline does not install Gatekeeper add-on | `aks-baseline.json`, `check {}`, `policy-test-azure` |
