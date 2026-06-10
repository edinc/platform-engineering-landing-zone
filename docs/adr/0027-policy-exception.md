# ADR-0027: Policy exception workflow and approver matrix

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 02 - subscription baseline and compliance alignment

## Context

The compliance baseline (ADR-0011) is audit-first, but some controls already
`Deny` (mandatory tags) and more will move to `Deny` as the tenant matures. A
brownfield tenant will have legitimate, temporary reasons to be out of
compliance. Without a defined, auditable exception path, teams either get blocked
with no escape hatch or the platform team disables controls globally - both are
unacceptable. Azure Policy provides exemptions (scoped, optionally time-bound,
with a category and a justification); we need a process wrapped around that
primitive.

## Decision

**Policy non-compliance is handled through time-bound Azure Policy exemptions in
the external ALZ policy workflow, requested and approved as code, never by
weakening or unassigning an initiative.**

1. **Mechanism.** The ALZ owner uses `azurerm_resource_policy_exemption` /
   `azurerm_subscription_policy_exemption` (or MG-scoped equivalents) with:
   - `exemption_category = "Waiver"` (accepted non-compliance) or `"Mitigated"`
     (compensating control exists);
   - a mandatory `expires_on` (time-bound; see matrix for maximum durations);
   - a `description` referencing the approval (PR or change ticket);
   - the narrowest possible scope (resource > resource group > subscription;
     never the whole MG hierarchy).

2. **Workflow.** Request -> review -> approve -> apply -> audit:
   - **Request:** a PR or change request in the ALZ-owned policy repository adds
     the exemption resource with justification, scope, and expiry, or fills the
     exception template in the runbook.
   - **Approve:** per the approver matrix below.
   - **Apply:** merged through the ALZ owner's normal IaC pipeline; the exemption
     is now in the ALZ policy state and auditable.
   - **Audit:** exemptions are reviewed before expiry; the subscription
     readiness-discovery script and Defender/Policy compliance reports surface
     active exemptions.

3. **Approver matrix.**

   | Exemption scope / effect | Maximum duration | Approver |
   |--------------------------|------------------|----------|
   | Single resource, `Audit`/DINE control | 90 days | Workload team lead + platform on-call |
   | Resource group, any effect | 90 days | Platform team lead |
   | Mandatory-tag `Deny` (any scope) | 30 days | Platform team lead (tags are cheap to fix; short leash) |
   | Subscription scope, or any CIS `Deny` once enforced | 30 days | Platform lead + security/compliance owner |
   | Break-glass / incident exemption | 7 days | Incident commander (retro-reviewed, ADR-0024) |

4. **No silent expiry extensions.** Renewing an exemption is a new request with a
   fresh approval; expired exemptions are not auto-renewed.

## Consequences

- Every deviation from the baseline is explicit, scoped, time-bound, and
  attributable in ALZ-owner git history/change records and in the Azure control
  plane.
- Controls are never globally weakened to accommodate one team; blast radius of
  an exception is bounded by scope.
- The brownfield onramp has a sanctioned escape hatch, which keeps audit-first
  rollout viable without blocking delivery.
- Operational overhead: someone must review exemptions before they expire; the
  discovery script and compliance reports make this a checklist, not archaeology.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Unassign or set the initiative to `Disabled` for an exception | Removes the control for everyone in scope, not just the exempt resource; defeats the baseline. |
| Permanent (no-expiry) exemptions | Non-compliance becomes invisible debt; violates the time-bound requirement. |
| Tag-based "skip" convention enforced only in policy logic | Harder to audit than first-class Azure exemptions and easy to abuse. |

## References

- [`docs/runbooks/policy-exception.md`](../runbooks/policy-exception.md)
- [ADR-0011: Compliance baseline](0011-compliance-baseline.md)
- [ADR-0024: Break-glass procedure](0024-break-glass.md)
- [Azure Policy exemption structure](https://learn.microsoft.com/azure/governance/policy/concepts/exemption-structure)
