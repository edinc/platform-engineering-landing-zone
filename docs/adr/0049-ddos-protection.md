# ADR-0049: DDoS protection posture

- Status: accepted
- Date: 2026-06-10
- Capability: connectivity & egress

## Context

Azure DDoS Network Protection is valuable for public, tier-0 workloads but adds
cost that is disproportionate for the MVP and especially the demo profile.
Connectivity & egress still creates public IPs for Azure Firewall and demo NAT
Gateway, so the baseline posture must be explicit.

## Decision

**The MVP does not enable Azure DDoS Network Protection by default. Public IPs
use Azure's always-on platform DDoS Basic protection unless a tier-0 public
workload triggers a specific upgrade decision.**

Network Protection must be revisited when any of these triggers appear:

1. a public-facing tier-0 workload is onboarded;
2. regulated production requirements mandate enhanced DDoS telemetry/mitigation;
3. multiple production ingress points justify amortizing the plan cost;
4. a security review requires DDoS Rapid Response or enhanced attack analytics.

## Consequences

- Demo and MVP cost remain lower.
- Public IPs still receive Azure platform DDoS Basic protection.
- Enhanced DDoS telemetry, cost protection, and Rapid Response are not available
  until a future plan is enabled.
- Any public tier-0 onboarding must explicitly revisit this ADR.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Enable DDoS Network Protection for every profile | Cost-prohibitive for demo and premature before public tier-0 workload requirements. |
| Never use DDoS Network Protection | Too weak for future public production workloads. |
| Per-workload unmanaged decisions | Fragments security posture and cost ownership. |

## References

- [`infrastructure/terraform/connectivity/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/connectivity/)
- [connectivity & egress](../how-it-works/connectivity-egress.md)
- [Azure DDoS Protection overview](https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview)
