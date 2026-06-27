# ADR-0008: Subscription vending

- Status: accepted
- Date: 2026-06-11
- Capability: tenancy vending

## Context

The platform needs a repeatable way to create workload subscriptions while
remaining brownfield-aware. Some tenants already have an ALZ subscription vending
process, while others expect this repository to own the vending composition. The
subscription baseline already assumes subscriptions may exist before this repo
touches them.

## Decision

**Subscription vending integrates with the existing ALZ process first, and uses
`Azure/lz-vending` when this repository owns subscription creation.**

1. Repo-owned subscription vending lives under
   `infrastructure/terraform/vending/subscription/`.
2. The composition pins `Azure/lz-vending` to commit
   `dee26d39d5d3fc5fb78feb7fe26d63e4d956c9be` (`v4.1.5`), the newest line
   compatible with this repo's Terraform 1.9 toolchain.
3. Externally-created subscriptions are handed to
   `infrastructure/terraform/vending/onboarding/`, which generates the subscription-baseline
   handoff and records ALZ placement evidence.
4. Vending requests are PR-driven and must pass the versioned request schema
   before any Terraform plan or apply.

## Consequences

- Brownfield tenants can keep their existing ALZ subscription lifecycle.
- Greenfield/demo tenants still get an IaC-first vending path.
- The pinned `Azure/lz-vending` module is archived upstream; migration to the
  AVM replacement is a future tracked upgrade, not an implicit tenancy vending change.
- The subscription baseline remains the source for Defender, diagnostics, budget, and cost-export
  baseline after a subscription exists.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Require this repo to create every subscription | Not brownfield-safe and duplicates existing ALZ vending processes. |
| Only document external vending | Leaves demo/greenfield paths without an executable Terraform composition. |
| Upgrade the whole repo to Terraform 1.10 for latest `lz-vending` | Too broad for tenancy vending and unnecessary for the documented deliverables. |

## References

- [Tenancy vending](../how-it-works/tenancy-vending-onboarding.md)
- [`infrastructure/terraform/vending/subscription/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/vending/subscription/)
- [`infrastructure/terraform/vending/onboarding/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/vending/onboarding/)
- [Terraform Registry: Azure/lz-vending](https://registry.terraform.io/modules/Azure/lz-vending/azurerm/latest)
