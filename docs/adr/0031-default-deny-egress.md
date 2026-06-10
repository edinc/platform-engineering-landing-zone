# ADR-0031: Default-deny egress and FQDN allowlist

- Status: accepted
- Date: 2026-06-10
- Stage: Stage 03 - connectivity, identity, and egress

## Context

The platform must prevent unreviewed outbound access while still allowing
required platform dependencies such as Azure control plane APIs, container
registries, GitHub, package managers, Ubuntu mirrors, Docker Hub, and Sigstore.
The demo profile must remain cost-conscious and cannot require Azure Firewall
Premium.

## Decision

**Non-demo egress is default-deny through Azure Firewall Premium with a curated
FQDN allowlist. Demo egress uses NAT Gateway and relies on later Cilium
FQDN-aware policies inside AKS.**

1. `nonprod` and `prod` create Azure Firewall Premium and a Firewall Policy.
   Unmatched traffic is denied by default; allowed destinations come from
   `policies/azure/firewall/allowlist.json`.
   Stage 04 appends AKS node/control-plane dependencies when AKS lifecycle is
   introduced.
2. Workload subnets route `0.0.0.0/0` to the firewall. The Stage 03 stack outputs
   the route table for later vending/subscription integration.
3. The allowlist JSON is static-validated in CI so required platform FQDNs cannot
   be removed accidentally.
   Ubuntu package mirrors are allowed only over HTTPS; platform base images and
   bootstrap scripts must rewrite apt sources away from default HTTP mirrors.
   Platform and workload ACRs use Private Link by default; public ACR exceptions
   are exact-registry FQDNs, not tenant-wide wildcards.
4. Egress exceptions are requested by PR/change request, reviewed by security,
   implemented as time-bound firewall and NetworkPolicy changes, and audited.
5. `demo` creates NAT Gateway only. Its lack of Azure-layer FQDN filtering is
   explicit and accepted for cost; Cilium FQDN policy becomes the enforcement
   point after Stage 04/07.

## Consequences

- Production egress has a central, reviewable choke point.
- The allowlist needs active lifecycle management as tools and registries change.
- Demo is cheaper but intentionally less protected at the Azure network layer.
- Some package ecosystems may require exception churn until golden paths converge
  on approved base images and registries.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Allow all outbound with monitoring only | Fails the secure-by-default posture. |
| Azure Firewall Premium in demo | Too costly for the demo profile. |
| NSG-only egress | NSGs cannot enforce FQDN allowlists. |
| Service mesh for egress | Deferred; no mesh in MVP. |

## References

- [`policies/azure/firewall/allowlist.json`](../../policies/azure/firewall/allowlist.json)
- [`docs/runbooks/egress-exception.md`](../runbooks/egress-exception.md)
- [`plan/stages/stage-03-connectivity-identity-egress.md`](../../plan/stages/stage-03-connectivity-identity-egress.md)
