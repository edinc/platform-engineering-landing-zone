# ADR-0030: Hub-and-spoke networking for MVP

- Status: accepted
- Date: 2026-06-10
- Capability: connectivity & egress

## Context

The platform needs shared egress inspection, Private DNS, Private Endpoint
placement, and later VPN/ExpressRoute integration. Virtual WAN can centralize
global routing, but the MVP optimizes for brownfield adoption, explicit
Terraform ownership, and low operational complexity.

## Decision

**The MVP uses a regional hub-and-spoke topology, not Virtual WAN.**

1. The connectivity-and-egress stack owns the hub VNet in the connectivity
   subscription.
2. Workload and platform spokes are linked/peered to the hub by later vending and
   platform stacks.
3. The hub reserves `GatewaySubnet`, `AzureFirewallSubnet`, `private-endpoints`,
   `shared-services`, and conditionally `AzureFirewallManagementSubnet` for
   forced tunneling.
4. Private DNS zones are centralized in the hub resource group and linked to the
   hub plus onboarded spokes.
5. VPN/ExpressRoute is reserved by subnet and documentation only for MVP.

## Consequences

- The MVP stays understandable and deployable in brownfield tenants.
- Route-table and DNS ownership are explicit and reviewable.
- Future global routing, large branch networks, or multi-region active-active may
  justify Virtual WAN or AKS Fleet during future-option planning.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Virtual WAN from day one | Higher cost/complexity than the MVP requires; global branch routing is not an initial requirement. |
| Per-spoke egress only | Duplicates firewall/DNS policy and weakens central governance. |
| Flat shared VNet | Poor blast-radius and ownership boundaries for workload subscriptions. |

## References

- [`infrastructure/terraform/connectivity/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/connectivity/)
- [Connectivity & egress](../how-it-works/connectivity-egress.md)
- [Azure Cloud Adoption Framework networking topology](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/traditional-azure-networking-topology)
