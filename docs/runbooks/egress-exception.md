# Egress exception workflow

Stage: 03 - connectivity, identity, and egress

Use this runbook when a workload or platform component needs outbound access
that is not already covered by
[`policies/azure/firewall/allowlist.json`](../../policies/azure/firewall/allowlist.json)
or by the relevant in-cluster NetworkPolicy/CiliumNetworkPolicy.

## Policy

All exceptions are explicit, reviewed, time-bound, and implemented as code.
Do not bypass the firewall, add broad wildcard destinations, or weaken namespace
default-deny policy for convenience.

## Request requirements

An exception request must include:

| Field | Required content |
|-------|------------------|
| Requester | Team, service owner, and on-call contact. |
| Destination | FQDNs, ports, protocols, and whether the destination is SaaS, Azure, or partner-hosted. |
| Source | Namespace/subnet/workload identity that needs the egress path. |
| Business justification | Why the connection is needed and what breaks without it. |
| Data classification | Highest data classification expected to traverse the connection. |
| Duration | Expiry date; default maximum is 90 days, 30 days for production internet egress. |
| Evidence | Vendor docs, API docs, or packet/log evidence proving the minimum required endpoints. |
| Rollback | How the platform team can safely remove the exception. |

## Workflow

1. **Request** - Open a PR or change request that updates the firewall allowlist
   and, where applicable, the namespace NetworkPolicy/CiliumNetworkPolicy.
2. **Review** - Platform and security reviewers check the destination scope,
   expiry, data classification, and whether a Private Endpoint or Azure-native
   integration can avoid public egress.
3. **Approve** - Use the approver matrix below. Emergency changes can be applied
   through break-glass but must be backfilled into git within one business day.
4. **Apply** - Merge through the normal Terraform/GitOps pipeline. For
   `nonprod`/`prod`, update Azure Firewall rules; for `demo`, update Cilium
   FQDN policy once Stage 07 is available.
5. **Audit** - Record the merged PR/change ID, owner, and expiry. Review
   exceptions at least monthly and before expiry.

## Approver matrix

| Scope | Maximum duration | Approver |
|-------|------------------|----------|
| Nonprod platform dependency | 90 days | Platform on-call |
| Production platform dependency | 30 days | Platform lead + security owner |
| Workload team dependency | 90 days | Workload owner + platform on-call |
| Broad wildcard or SaaS domain family | 30 days | Platform lead + security owner |
| Incident/break-glass | 7 days | Incident commander, retro-reviewed |

## Implementation checklist

1. Add the narrowest FQDNs to `policies/azure/firewall/allowlist.json`; avoid
   `*`, top-level wildcards, and destinations that are not backed by evidence.
2. Run `make policy-test-azure`.
3. For non-demo profiles, run Terraform validation/plan for
   `infrastructure/terraform/connectivity`.
4. Add or update the namespace egress policy in the GitOps repo when the source
   is Kubernetes.
5. Confirm logs show allowed traffic only from the approved source.
6. Create a removal task dated before expiry.

## Demo profile note

The demo profile uses NAT Gateway only. Azure does not enforce FQDN rules there;
Cilium FQDN-aware policy is the enforcement point after the AKS/Cilium stages are
available. Do not treat a demo exception as approval for nonprod/prod firewall
egress.
