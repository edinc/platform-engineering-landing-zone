# ADR-0011: Compliance baseline

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 02 - subscription baseline and compliance alignment

## Context

The platform must align every onboarded subscription with the organization's
Azure compliance baseline, but this repository no longer creates the Azure
Landing Zone itself. Management groups, tenant/MG-scoped policy assignments, and
central shared services are assumed to exist before Stage 02 runs.

The repo still needs clear, testable guarantees:

- subscription onboarding must not weaken inherited ALZ/CIS controls;
- every subscription must receive the platform's subscription-scoped hardening
  where this repo has responsibility;
- policy definitions used by the platform must remain reviewable and validated,
  even when assignment is performed by the external ALZ owner.

## Decision

**Compliance baseline = inherited organizational ALZ/CIS controls plus
subscription-scoped hardening by this repo.**

1. **Inherited controls.** The existing ALZ is responsible for tenant and
   management-group policy assignments such as CIS Microsoft Azure Foundations
   Benchmark v2, regulated initiatives, tag enforcement, private-link posture,
   and other broad governance effects. Stage 02 verifies and documents those
   assumptions; it does not create or mutate them.

2. **Subscription-scoped hardening.** The Stage 02 Terraform stack configures
   controls that are naturally scoped to a subscription:
   - Microsoft Defender for Cloud plan pricing;
   - subscription Activity Log diagnostics to an existing central Log Analytics
     workspace;
   - optional subscription budget;
   - optional Cost Management export to an existing platform/ALZ storage
     container.

3. **Reference policy pack.** Custom initiatives remain under
   `policies/azure/initiatives/` as an optional/reference policy pack for ALZ
   administrators:
   - `tag-baseline` - Deny missing mandatory tags on resources and resource
     groups.
   - `private-link-required` - Audit public network access for selected data
     services; Storage/PostgreSQL can be tightened to Deny by the ALZ owner.
   - `aks-baseline` - Audit AKS identity controls and deliberately exclude the
     AKS Policy (Gatekeeper) add-on.

4. **Static enforcement of platform invariants.** `make policy-test-azure`
   validates the reference policy pack in credential-free CI: pinned built-in
   GUIDs, mandatory tag coverage, no Gatekeeper add-on, no AKS Deny effect, and
   Audit default for private-link.

5. **Exception handling.** Deviations from inherited policy are handled through
   scoped, time-bound Azure Policy exemptions owned by the external ALZ process
   and documented through ADR-0027/runbooks. This repo must not weaken or remove
   shared assignments to accommodate one subscription.

## Consequences

- Stage 02 becomes much simpler: it can onboard one existing subscription at a
  time without requiring tenant root or management-group permissions.
- The ALZ owner remains accountable for broad policy posture; this repo remains
  accountable for subscription readiness and hardening.
- The policy JSON remains useful and testable, but it is no longer coupled to
  the Stage 02 Terraform apply.
- Compliance drift must be detected through readiness discovery and inherited
  policy/compliance reports, not through this stack creating assignments.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Continue creating management groups and MG-scoped policy here | Too much tenant-wide responsibility for the user's current need; duplicates an ALZ that is assumed to already exist. |
| Delete all Azure Policy initiative files | Loses a useful, validated reference pack and removes CI coverage for tag/Gatekeeper invariants. |
| Assign policies at subscription scope from this stack | Risks conflicting with inherited ALZ assignments and splits governance ownership. |
| Rely only on documentation for tag/Gatekeeper rules | CI would no longer catch accidental weakening of the reference policy pack. |

## References

- [`plan/stages/stage-02-subscription-baseline.md`](../../plan/stages/stage-02-subscription-baseline.md)
- [`infrastructure/terraform/subscription-baseline/`](../../infrastructure/terraform/subscription-baseline/)
- [`policies/azure/initiatives/`](../../policies/azure/initiatives/)
- [`scripts/policy/validate_azure_initiatives.py`](../../scripts/policy/validate_azure_initiatives.py)
- [ADR-0026: AVM module pinning and the subscription-baseline composition choice](0026-avm-modules.md)
- [ADR-0027: Policy exception workflow and approver matrix](0027-policy-exception.md)
- [ADR-0036: Kyverno as single in-cluster policy engine](README.md)
- [ADR-0047: Policy testing split](0047-policy-testing-split.md)
