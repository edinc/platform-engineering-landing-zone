# ADR-0028: Subscription topology and ALZ ownership boundary

- Status: accepted
- Date: 2026-06-09
- Capability: subscription baseline

## Context

Subscriptions are the unit of billing, quota, and strong blast-radius isolation,
but this repository now assumes an Azure Landing Zone already exists. That means
subscription creation and placement under management groups are either handled
by an external ALZ/vending process or by a later tenancy-vending integration, not by the
subscription-baseline stack.

The subscription baseline stack still needs a clear topology assumption so it can onboard the
right subscriptions without moving them.

## Decision

**An external ALZ owner is responsible for subscription placement. This repo
baselines subscriptions after they exist and are placed in the appropriate ALZ
management group.**

1. **Platform subscriptions** are still expected by function:
   - management/monitoring subscription for shared observability and cost
     destinations;
   - connectivity subscription for hub networking (connectivity & egress);
   - platform subscription for AKS/ACR/Key Vault/Postgres shared services
     (platform shared services).

2. **Workload subscriptions** are still separated by environment and blast
   radius:
   - `prod`: dedicated subscriptions per workload domain where required;
   - `nonprod`: separate non-production subscription(s);
   - `demo`: a single subscription can host the demo profile to minimize cost.

3. **The subscription baseline does not move subscriptions.** It accepts `subscription_id` and
   hardens that existing subscription. If a subscription is in the wrong
   management group, the operator fixes placement through the external ALZ/vending
   process before applying this stack.

4. **Tenancy vending integrates rather than assumes ownership.** If this repo
   later owns vending, it may use `Azure/lz-vending`; otherwise it opens
   onboarding PRs for externally-created subscriptions and then runs the subscription
   baseline.

## Consequences

- The platform can be adopted in brownfield tenants without requiring tenant root
  management-group permissions in this repository.
- The boundary between enterprise ALZ governance and platform subscription
  hardening is explicit.
- Subscription moves remain high-impact operations handled by the ALZ owner, not
  a side effect of this baseline.
- `demo` remains cheap and simple while `nonprod`/`prod` can use stronger
  subscription isolation.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| The subscription baseline creates the management-group hierarchy and associations | Too broad for the desired subscription-only baseline; duplicates existing ALZ work. |
| Auto-detect and move subscriptions to expected MGs | Not brownfield-safe; silently changes inherited policy/RBAC. |
| Single subscription for every environment | No billing/quota/blast-radius isolation between prod and non-prod; unacceptable for production. |
| Tags/RBAC only, no subscription boundary | Tags do not provide a hard billing/quota/security boundary. |

## References

- [Subscription baseline](../how-it-works/foundation.md)
- [`infrastructure/terraform/subscription-baseline/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/subscription-baseline/)
- [ADR-0008: Subscription vending](0008-subscription-vending.md)
- [ADR-0011: Compliance baseline](0011-compliance-baseline.md)
