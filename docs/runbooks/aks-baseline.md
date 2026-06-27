# AKS baseline operations

Capability: platform shared services

This runbook captures the day-2 AKS baseline that the platform Terraform stack
establishes and later GitOps stages extend.

## Baseline checks

| Control | Expected state |
|---------|----------------|
| API access | Private cluster; no `api_server_authorized_ip_ranges`. |
| Identity | Managed identity, OIDC issuer, Workload Identity enabled. |
| RBAC | Managed Entra integration with Azure RBAC; local accounts disabled. |
| Network | Azure CNI Overlay, Cilium dataplane and network policy. |
| Egress | `userDefinedRouting` when `firewall_private_ip_address` is supplied. |
| Nodes | System pool tainted for critical add-ons, plus autoscaled default user pool. |
| Maintenance | Stable auto-upgrade channel, NodeImage OS upgrade channel, weekly window. |
| Image hygiene | Image cleaner enabled. |

## Upgrade ring

1. Apply Terraform in `demo` first when a demo environment exists.
2. Promote to `nonprod` after smoke tests and policy validation.
3. Promote to `prod` during the approved maintenance window.

## Node-pool changes

Use Terraform for node-pool VM size, scaling bounds, subnet, and zone changes.
Do not mutate node pools manually in the Azure portal except during an incident;
backfill any incident change into Terraform before closing the incident.

## Known follow-ups

- AKS Backup is documented as a platform reliability capability, but the initial
  Terraform slice does not yet create backup vault/policy resources.
- AKS Node Auto-Provisioning is tracked as a follow-up until the pinned
  `azurerm` provider exposes the required schema.
- Namespace-level Pod Security Admission and Kyverno policies are owned by Stage
  07 GitOps.
