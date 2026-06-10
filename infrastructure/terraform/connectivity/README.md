# Connectivity (Stage 03)

Hub networking, egress control, Private DNS, AMPLS, and Private Endpoint
retrofit primitives for the connectivity subscription. The stack is
profile-aware:

| Profile | Egress resource | Enforcement boundary |
|---------|-----------------|----------------------|
| `demo` | NAT Gateway | Azure provides outbound SNAT only; FQDN allow/deny is enforced later by Cilium policies in-cluster. |
| `nonprod` / `prod` | Azure Firewall Premium | Default-deny Firewall Policy with the curated FQDN allowlist in `policies/azure/firewall/allowlist.json`. |

Related decisions: [ADR-0030](../../../docs/adr/0030-hub-and-spoke.md),
[ADR-0031](../../../docs/adr/0031-default-deny-egress.md),
[ADR-0048](../../../docs/adr/0048-runner-connectivity.md), and
[ADR-0049](../../../docs/adr/0049-ddos-protection.md).

## What this stack owns

| Capability | Resource | Notes |
|------------|----------|-------|
| Hub network | `azurerm_virtual_network`, `azurerm_subnet` | Creates `GatewaySubnet`, `AzureFirewallSubnet`, `private-endpoints`, `shared-services`, and optionally `AzureFirewallManagementSubnet`. |
| Non-demo egress | `azurerm_firewall`, `azurerm_firewall_policy`, route table | Premium Firewall Policy is allowlist-only; unmatched outbound traffic is denied by default. |
| Demo egress | `azurerm_nat_gateway` | Cost-conscious profile; no Azure-layer FQDN filtering. |
| Private DNS | `azurerm_private_dns_zone`, VNet links | MVP zones for KV, ACR, Storage blob/dfs, Postgres Flexible, AKS API, Service Bus, and Azure Monitor/AMPLS. |
| AMPLS | `azurerm_monitor_private_link_scope`, Private Endpoint | PrivateOnly ingestion/query modes; linked resources are supplied as inputs. |
| Hub peerings | `azurerm_virtual_network_peering` | Creates hub-to-spoke peerings for supplied spokes and reverse peerings only when the spoke is in the connectivity subscription. |
| Stage 01 PE retrofit | `azurerm_private_endpoint` | Generic map supports Terraform state blob and seed Key Vault Private Endpoints after the hub exists. |

## What this stack deliberately does not own

- Workload spoke VNet creation (Stage 05 vending).
- AKS subnets and cluster lifecycle (Stage 04).
- Cilium FQDN-aware policies for demo (Stage 07, after AKS/Cilium exists).
- VPN/ExpressRoute gateways; `GatewaySubnet` is reserved for a later integration.
- Forced tunneling only creates the Azure Firewall management split in MVP. The
  on-premises next-hop UDR is added with the later VPN/ExpressRoute integration.
- Tenant/MG-scoped policy or RBAC owned by the external ALZ.

## State backend

State lives in the Stage 01 account, container `connectivity`, with a key such as
`nonprod/connectivity.tfstate`. Copy `backend.hcl.example` to `backend.hcl`,
fill `resource_group_name` and `storage_account_name` from `_bootstrap` outputs,
then run:

```bash
terraform init -backend-config=backend.hcl
```

CI validates credential-free with `terraform init -backend=false`.

## Key inputs

| Input | Required? | Purpose |
|-------|-----------|---------|
| `tenant_id`, `subscription_id` | yes | Existing connectivity subscription target. |
| `profile` | yes | Selects demo NAT versus nonprod/prod Firewall Premium. |
| `spoke_virtual_network_ids` | no | Creates hub-side peerings and links every Private DNS zone to brownfield or vended spokes. Cross-subscription reverse peerings stay with the spoke owner/vending stack. |
| `workload_subnet_ids` | no | Associates in-subscription workload subnets with the Firewall default-route table. |
| `workload_subnet_source_prefixes` | with `workload_subnet_ids` | Source CIDRs for routed workload subnets; keys must match `workload_subnet_ids`. |
| `firewall_allowlist_source_addresses` | no | Additional source CIDRs allowed to use the curated egress FQDNs; the `shared-services` subnet is always included and vending should add approved workload prefixes. |
| `private_endpoints` | no | Creates Private Endpoints into `private-endpoints`, including Stage 01 state/KV retrofit. |
| `enable_monitor_private_link_scope` | no | Disabled by default until a platform-owned or explicitly approved monitor resource exists. |
| `monitor_linked_resource_ids` | when AMPLS enabled | Links Log Analytics, App Insights, or Data Collection Endpoints into AMPLS. |
| `monitor_private_link_query_access_mode` | no | Defaults to `PrivateOnly`; use `Open` only as a documented brownfield exception while onboarding monitor resources. |
| `firewall_base_policy_id` | no | Optional external ALZ parent Firewall Policy inherited by the Stage 03 child egress policy. |

AMPLS `PrivateOnly` modes affect every linked monitor resource. Link only a
platform-owned or explicitly approved workspace/component whose consumers have
the required Private DNS and Private Endpoint paths; do not attach a shared ALZ
workspace without its owner's approval.

Keep `enable_monitor_private_link_scope = false` for the first hub apply when no
platform-owned monitor resource exists yet. Re-enable AMPLS once Stage 04/08
monitoring resources are available and approved for `PrivateOnly` access.

## Validation

```bash
make terraform-validate
make policy-test-azure
```

`make policy-test-azure` also validates the firewall allowlist schema and
required FQDN coverage.

## Acceptance-criteria mapping

| # | Criterion | Where |
|---|-----------|-------|
| 1 | New workload spokes peer/link to hub with one variable | `spoke_virtual_network_ids` creates hub-side peering and DNS links; same-subscription spokes also get reverse peering. Cross-subscription reverse peering is handled by Stage 05/spoke ownership. |
| 2 | Non-demo egress is allowlist-only through Firewall | `azurerm_firewall_policy_rule_collection_group.egress_allowlist`, route-table output. Azure Monitor deny alerting is still a follow-up item for this Stage 03 implementation. |
| 3 | Demo relies on Cilium FQDN policy, not Azure Firewall | `profile = "demo"` creates NAT Gateway only and returns `firewall_id = null`. |
| 4 | Private DNS and AMPLS are private by default | `private-dns.tf`, `enable_monitor_private_link_scope`. |
| 5 | RBAC uses groups | Implemented in the sibling `../identity/` stack. |
| 6 | PIM activation alerting prepared | Identity stack configures PIM policy; activation alerting remains a follow-up item with monitoring integration. |
| 7 | Stage 01 Phase-2 PE retrofit supported | `private_endpoints` map and tfvars examples for state blob + seed Key Vault; disabling public access remains the paired `_bootstrap` Phase-2 apply. |

Stage 04 appends AKS node/control-plane dependencies to the firewall allowlist
when the cluster lifecycle is introduced. The Stage 03 allowlist only covers
platform bootstrap, source, registry, package-manager, and signing dependencies.
Ubuntu package egress is HTTPS-only; base images and node bootstrap scripts must
use HTTPS apt mirrors instead of default HTTP sources.
Workload or platform ACR access should use Private Link by default; public ACR
exceptions must be exact registry FQDNs reviewed through the egress exception
workflow.
If `firewall_base_policy_id` is set, the parent policy must be Premium-tier to
match the Stage 03 Premium child policy and Firewall.

Demo workload subnets created in later stages must associate the exported
`nat_gateway_id`; Stage 03 attaches NAT only to the hub `shared-services` subnet.
