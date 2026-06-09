# ADR-0011: Compliance baseline

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 02 - ALZ baseline and compliance baseline

## Context

The landing zone needs a named, auditable compliance baseline that can be
asserted against every subscription, plus a rollout model that does not break
existing (brownfield) resources on day one. Stage 02 acceptance criteria require
CIS Foundations v2 plus ALZ initiatives, mostly at `Audit`/`DeployIfNotExists`,
with exactly one pre-approved `Deny` (mandatory tags), and a documented path to
tighten effects later (acceptance criteria 2 and 3).

The chosen ALZ composition is a native `azurerm` build rather than a packaged ALZ
module (ADR-0026), so "ALZ initiatives" here means a curated set of built-in
policies and custom initiatives we assign ourselves.

## Decision

**Compliance baseline = CIS Microsoft Azure Foundations Benchmark v2 (built-in
initiative) assigned at the `alz` management group, plus three custom initiatives
(`tag-baseline`, `private-link-required`, `aks-baseline`), with audit-first
effects and a single pre-approved `Deny`.**

1. **CIS v2** (`06f19060-9e68-4070-92ca-f15cc126059e`) is assigned at `alz`. It is
   **evaluation-only** by default (`cis_enforce = false`, assignment
   `enforce = false` / DoNotEnforce). Compliance is still evaluated and scored;
   no broad denies are introduced during the tenant grace period. The assignment
   carries a SystemAssigned identity so it can be flipped to enforced later
   without recreation; the initiative's remediation roles are granted to that
   identity as part of enabling enforcement.

2. **Custom initiatives** are defined as JSON in
   `policies/azure/initiatives/` (the source of truth) and rendered into
   `azurerm_policy_set_definition` resources:
   - `tag-baseline` - **Deny** on missing mandatory tags, on both resources and
     resource groups. This is the only `Deny` at Stage 02 (criterion 3).
   - `private-link-required` - **Audit** for public network access on Storage,
     Key Vault, Container Registry, and PostgreSQL flexible servers. The Storage
     and PostgreSQL members are configurable to **Deny**; the Key Vault and
     Container Registry members are audit-only built-ins (no `Deny` effect) and
     stay audit-only.
   - `aks-baseline` - **Audit** for disabled local accounts and managed
     identities; it deliberately excludes the AKS Policy (Gatekeeper) add-on
     (ADR-0036, criterion 8).

3. **Audit-first rollout.** Every effect except the tag `Deny` defaults to
   `Audit`/`DeployIfNotExists`. Effects move to `Deny` only after the exemption
   inventory is drained, through the policy-exception workflow (ADR-0027).

4. **Static enforcement of the criteria.** Because Terraform `check {}` blocks
   only run at plan/apply, a credential-free guard
   (`scripts/policy/validate_azure_initiatives.py`, `make policy-test-azure`)
   asserts criteria 3 and 8 in CI against the initiative JSON.

The built-in policy GUIDs are pinned in `locals.tf` and the initiative JSON, and
verified against the canonical `Azure/azure-policy` repository.

## Consequences

- A subscription's posture is measurable against CIS v2 from day one without the
  risk of denying existing workloads.
- The only thing that can block a deployment at Stage 02 is a missing mandatory
  tag, which is already enforced in CI by the Rego gate (ADR-0047), so the
  control-plane `Deny` and the plan-time gate agree.
- Tightening effects is a deliberate, reviewed change, not a default, which keeps
  the brownfield onramp safe (see the brownfield runbook).
- Enabling CIS enforcement later requires granting remediation roles to the
  assignment identity; this is documented rather than pre-provisioned to avoid
  standing privilege while the initiative is evaluation-only.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Assign CIS v2 with default (enforced) effects immediately | Introduces broad denies across a brownfield tenant; violates the audit-first criterion and risks blocking existing resources. |
| Microsoft cloud security benchmark (MCSB) only | CIS v2 is the named baseline in the stage spec; MCSB is enabled implicitly via Defender and can be layered later. |
| Put effects only in the assignments, not the initiatives | Loses a reusable, named initiative as the unit of governance and makes the tag/private-link/aks intent harder to audit. |
| Rely solely on Terraform `check {}` for criteria 3/8 | `check {}` does not run under `terraform validate`, so CI would not catch a regression; the Python guard closes that gap. |

## References

- [`plan/stages/stage-02-alz-baseline.md`](../../plan/stages/stage-02-alz-baseline.md)
- [`infrastructure/terraform/alz/assignments.tf`](../../infrastructure/terraform/alz/assignments.tf)
- [`policies/azure/initiatives/`](../../policies/azure/initiatives/)
- [`scripts/policy/validate_azure_initiatives.py`](../../scripts/policy/validate_azure_initiatives.py)
- [ADR-0026: AVM module pinning and the ALZ composition choice](0026-avm-modules.md)
- [ADR-0027: Policy exception workflow and approver matrix](0027-policy-exception.md)
- [ADR-0036: Kyverno as single in-cluster policy engine](README.md)
- [ADR-0047: Policy testing split](0047-policy-testing-split.md)
