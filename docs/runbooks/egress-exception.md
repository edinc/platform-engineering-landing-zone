# Egress exception workflow

Capability: connectivity & egress

Use this runbook when a workload or platform component needs outbound access
that is not already covered by
[`policies/azure/firewall/allowlist.json`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/policies/azure/firewall/allowlist.json)
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

1. **Request** - Use the Backstage `request-egress-exception` template or open a
   PR that updates the firewall allowlist and, where applicable, the namespace
   NetworkPolicy/CiliumNetworkPolicy. The template creates a reviewable patch
   under `policies/azure/firewall/exception-patches/` plus a demo-profile Cilium
   policy draft under    `platform-gitops/clusters/overlays/<environment>/network/egress-exceptions/`.
2. **Review** - Platform and security reviewers check the destination scope,
   expiry, data classification, and whether a Private Endpoint or Azure-native
   integration can avoid public egress.
3. **Approve** - Use the approver matrix below. Emergency changes can be applied
   through break-glass but must be backfilled into git within one business day.
4. **Apply** - Merge through the normal Terraform/GitOps pipeline. For
   `nonprod`/`prod`, update Azure Firewall rules; for `demo`, update Cilium
   FQDN policy once GitOps networking policy is available.
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

Backstage-generated egress exceptions use firewall collection priorities
`800-899`. Keep priorities unique across active exception patches and active
allowlist collections; recycle priorities only after the expiry sweep removes the
old exception.

## Implementation checklist

1. Add the narrowest FQDNs to `policies/azure/firewall/allowlist.json`; avoid
   `*`, top-level wildcards, and destinations that are not backed by evidence.
   If the request came from Backstage, apply the generated patch into
   `allowlist.json` before merging by copying only `name`, `priority`, `action`,
   and `rules` from the generated `collection`; keep patch-only metadata in the
   patch file for audit context.
2. Run `make policy-test-azure`.
3. For non-demo profiles, run Terraform validation/plan for
   `infrastructure/terraform/connectivity`.
4. Add or update the namespace egress policy in the GitOps repo when the source
   is Kubernetes. Backstage requests generate
   `platform-gitops/clusters/overlays/<environment>/network/egress-exceptions/<team>-<exception>.yaml`.
   Add the new filename to
   `platform-gitops/clusters/overlays/<environment>/network/egress-exceptions/kustomization.yaml`
   and preserve existing entries so only the target environment reconciles the
   active exception.
5. Confirm logs show allowed traffic only from the approved source.
6. Confirm `egress-exception-sweep.yml` opens a cleanup PR after expiry, or
   manually remove the firewall collection, generated patch, Cilium policy, and
   kustomization entry before expiry.

## Demo profile note

The demo profile uses NAT Gateway only. Azure does not enforce FQDN rules there;
Cilium FQDN-aware policy is the enforcement point after the AKS/Cilium stages are
available. Do not treat a demo exception as approval for nonprod/prod firewall
egress.
