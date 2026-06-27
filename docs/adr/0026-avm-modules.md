# ADR-0026: AVM module pinning, upgrade cadence, and the subscription-baseline composition choice

- Status: accepted
- Date: 2026-06-09
- Capability: subscription baseline

## Context

Earlier subscription baseline planning considered `Azure/caf-enterprise-scale` or
`Azure/avm-ptn-alz` to create the ALZ management-group and policy foundation.
The scope has changed: an Azure Landing Zone is assumed to already exist, and
this repository now owns only subscription onboarding/hardening.

That makes ALZ pattern modules unnecessary for subscription baseline. The remaining resources
are small, subscription-scoped `azurerm` resources that must continue to pass
credential-free CI (`terraform init -backend=false && terraform validate`,
TFLint, Checkov) with no Azure connection.

## Decision

**Build subscription baseline as a native `azurerm` subscription-baseline composition under
`infrastructure/terraform/subscription-baseline/`. Do not adopt
`Azure/caf-enterprise-scale`, `Azure/avm-ptn-alz`, or another ALZ pattern module
for this capability.**

1. **Subscription-baseline composition.** Defender pricing, Activity Log
   diagnostics, budgets, and optional Cost Management exports are authored
   directly with `azurerm` resources.

2. **External ALZ boundary.** Management groups, MG-scoped policy assignments,
   central Log Analytics workspaces, and cost-export storage accounts are inputs
   or prerequisites owned outside this stack.

3. **AVM usage policy.** When a later capability adopts an AVM module it MUST:
   - pin an exact GA version in that stack's `versions.tf`/module block;
   - validate credential-free in CI;
   - be recorded in the audit table below.

4. **Upgrade cadence.** AVM and provider upgrades land as dedicated, reviewed PRs
   (not auto-merged), at most monthly unless a security fix requires sooner. Each
   upgrade re-runs the full validate/lint/policy gates and a relevant `demo`
   plan where credentials are available.

5. **Provider pinning.** `azurerm ~> 4.14`, `terraform >= 1.9.0, < 2.0.0`,
   mirrored from the `_bootstrap` stack for consistency.

### AVM / ALZ module audit (subscription baseline)

| Module | Version | GA? | Decision |
|--------|---------|-----|----------|
| `Azure/caf-enterprise-scale` | n/a | GA | **Not adopted** - creates tenant/MG ALZ resources that are now external prerequisites. |
| `Azure/avm-ptn-alz` | n/a | Pattern module | **Not adopted** - same scope mismatch; revisit only if this repo later owns ALZ creation again. |
| `Azure/lz-vending` | n/a | Microsoft-maintained | **Deferred to tenancy vending** - used only if this repo owns vending rather than consuming externally-created subscriptions. |
| `Azure/avm-res-*` | n/a | Mixed | **Deferred to later capabilities** - adopt per resource when GA; pin and audit at that time. |

This table is updated as AVM modules are adopted in later capabilities.

## Consequences

- The subscription baseline no longer needs tenant root or management-group permissions.
- The stack is smaller, easier to validate without credentials, and less likely
  to duplicate or conflict with an existing enterprise ALZ.
- If the repo later needs to create ALZ resources, that is a separate ADR and
  state/address migration, not an implicit extension of this capability.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Keep the native ALZ/MG composition from the previous PR version | Still owns tenant-wide resources the user no longer wants this repo to manage. |
| `Azure/caf-enterprise-scale` | Too broad for a subscription-only baseline and duplicates existing ALZ ownership. |
| `Azure/avm-ptn-alz` | Same scope mismatch; adds ALZ lifecycle ownership instead of consuming it. |
| Wrap the few subscription resources in a custom module immediately | Premature abstraction; keep the stack direct until a second consumer proves reuse pressure. |

## References

- [Subscription baseline](../how-it-works/foundation.md)
- [`infrastructure/terraform/subscription-baseline/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/subscription-baseline/)
- [ADR-0001: Primary IaC](0001-iac.md)
- [ADR-0048: Runner connectivity model](0048-runner-connectivity.md)
