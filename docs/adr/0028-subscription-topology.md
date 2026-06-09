# ADR-0028: Subscription topology

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 02 - ALZ baseline and compliance baseline

## Context

The management-group hierarchy (Stage 02) defines where governance applies, but
the platform also needs a decision on how subscriptions map onto that hierarchy
across the three profiles (`demo`, `nonprod`, `prod`). Subscriptions are the unit
of billing, quota, and a strong security/blast-radius boundary. The decision must
be brownfield-safe: associating an existing subscription to a management group
must be optional and must not assume an empty subscription.

The MG hierarchy is:

```
Tenant Root
└── alz
    ├── platform
    │   ├── management      (logging, Defender, central platform tooling)
    │   ├── connectivity    (hub networking, egress - Stage 03)
    │   └── identity        (platform identity - later stage)
    ├── landingzones
    │   ├── corp            (internal-facing workloads)
    │   └── online          (external-facing workloads)
    ├── sandbox             (experimentation, relaxed policy)
    └── decommissioned      (quarantine before deletion)
```

## Decision

**Map subscriptions to management groups by function and environment, with
dedicated per-environment subscriptions for `nonprod` and `prod`, and a single
shared subscription for `demo`. Subscription-to-MG association is optional and
data-driven so brownfield tenants opt in explicitly.**

1. **Platform subscriptions** live under `platform`:
   - a **management** subscription (under `platform/management`) holds the central
     Log Analytics workspace, Defender configuration, and cost exports;
   - **connectivity** and **identity** subscriptions are provisioned in their
     owning stages and associated to the matching MG.

2. **Workload subscriptions** live under `landingzones`:
   - `prod`: dedicated subscriptions per workload domain under `corp` / `online`,
     one environment per subscription (strong prod isolation);
   - `nonprod`: dedicated subscription(s) per environment (e.g. dev, test) under
     the same MGs, separate from prod;
   - `demo`: a **single** subscription used for everything, associated where
     convenient, to keep cost and setup minimal.

3. **Association is optional.** `subscription_associations` in the ALZ stack is a
   map defaulting to empty; nothing is moved unless an operator provides the
   subscription ID and target MG. This is the brownfield-safe default - the MG
   hierarchy can be created and evaluated before any subscription is moved.

4. **`sandbox` and `decommissioned`** receive subscriptions on demand: sandbox for
   time-boxed experiments under relaxed policy, decommissioned as a quarantine MG
   (deny-most) for subscriptions awaiting deletion.

## Consequences

- `prod` blast radius is contained at the subscription boundary; a misconfigured
  non-prod change cannot affect prod quota, billing, or resources.
- `demo` stays cheap and simple (one subscription), matching the cost-conscious
  profile, at the cost of weaker isolation - acceptable for demos.
- Moving a subscription between MGs changes its inherited policy/RBAC and is a
  high-impact operation; it is deliberately operator-initiated and documented in
  the brownfield runbook rather than implied by the hierarchy.
- Per-environment subscriptions for nonprod/prod increase subscription count and
  vending work (Stage 05), which is the intended trade for isolation.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Single subscription for all environments | No billing/quota/blast-radius isolation between prod and non-prod; unacceptable for prod. |
| One subscription per workload but shared across environments | Mixes prod and non-prod in one blast radius and complicates quota and access boundaries. |
| Auto-associate all discovered subscriptions to MGs | Not brownfield-safe; silently re-parents existing subscriptions and changes their inherited policy. |
| Environment encoded only via tags/RBAC, not subscriptions | Tags do not provide a hard billing/quota/security boundary. |

## References

- [`plan/stages/stage-02-alz-baseline.md`](../../plan/stages/stage-02-alz-baseline.md)
- [`infrastructure/terraform/alz/management-groups.tf`](../../infrastructure/terraform/alz/management-groups.tf)
- [ADR-0008: Subscription vending (seeded, Stage 05)](README.md)
- [ADR-0011: Compliance baseline](0011-compliance-baseline.md)
