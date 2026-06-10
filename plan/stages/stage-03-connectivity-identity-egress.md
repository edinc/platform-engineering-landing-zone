# Stage 03 — Connectivity, identity, and egress

## Goal

Stand up the hub network with Private DNS, define the **default-deny egress**
posture, finalise Entra identity primitives (groups, PIM, RBAC), and provide a
documented exception workflow.

## Scope (in)

### Connectivity (in the `connectivity` subscription)

- Hub VNet with subnets: `GatewaySubnet`, `AzureFirewallSubnet`,
  `private-endpoints`, `shared-services`, and (conditional)
  `AzureFirewallManagementSubnet` only when **forced tunneling** is enabled.
- **Azure Firewall** — Premium SKU for `prod`/`nonprod`.
- **`demo` egress** — **NAT Gateway only** (no FQDN-aware egress at the
  Azure layer). For the demo profile, fine-grained egress restrictions are
  enforced **inside the cluster** via Cilium FQDN-aware NetworkPolicies
  (see below). This trade-off is documented in ADR-0031.
- Firewall policies (parent/child hierarchy owned by the existing ALZ or this
  connectivity stack, child per platform/workload subscription): default-deny outbound,
  FQDN allowlist for: Azure Resource Manager, ACR endpoints, Microsoft
  Container Registry, ghcr.io, GitHub API, npmjs, pypi, Docker Hub, Ubuntu
  archive, **Sigstore** (`rekor.sigstore.dev`, `fulcio.sigstore.dev`,
  `tuf.sigstore.dev`), etc. (curated list in
  `policies/azure/firewall/allowlist.json`).
- **UDRs** on every workload subnet forcing 0.0.0.0/0 → Firewall.
- **Private DNS zones** — scoped to MVP services only: KV
  (`privatelink.vaultcore.azure.net`), ACR (`privatelink.azurecr.io`), Storage
  (`privatelink.blob.core.windows.net` + `dfs` for ADLS Gen2), Postgres
  Flexible (`privatelink.postgres.database.azure.com`), AKS API
  (`privatelink.<region>.azmk8s.io`), Service Bus
  (`privatelink.servicebus.windows.net`), Monitor (see AMPLS below). Linked
  to hub + application VNets via Private DNS zone groups. OpenAI/Cosmos
  zones added only when a workload arrives that uses them.
- **Azure Monitor Private Link Scope (AMPLS)** — required for the
  observability stack to function fully behind private endpoints; private
  DNS zones for Log Analytics, App Insights, Monitor ingestion linked via
  AMPLS, not only via the per-resource Private DNS zones.
- **DDoS decision** — DDoS Network Protection **not** enabled at MVP
  (cost-prohibitive on the demo profile); recorded as ADR-0049 with trigger:
  any public-facing tier-0 workload. Azure DDoS Basic (free, always-on) is
  used by default for public IPs.
- **VPN / ExpressRoute placeholder** (not deployed in MVP; documented).
- **Private Endpoints standards**: every PaaS resource gets a PE; public
  network access disabled by policy.
- **Stage 01 retrofit** — execute the Phase 2 of Stage 01: replace
  IP-allowlisted public endpoints on the bootstrap state account and seed
  KV with Private Endpoints into `private-endpoints` subnet; disable
  public network access.

### Identity

- **Entra ID groups** (created via Terraform `azuread` provider):
  - `pe-platform-admins`, `pe-platform-operators`, `pe-platform-readers`.
  - `pe-app-team-<name>` (template).
- **PIM** activation policy: max 8h, MFA required, approval required for prod.
- **RBAC role assignments** at subscription/resource-group scope use groups, not
  users; MG-scope assignments remain with the external ALZ owner unless a later
  ADR explicitly brings them into this repo.
- **Custom roles** documented in `docs/adr/0029-custom-roles.md`:
  e.g., `Platform Operator` (subset of Contributor without IAM mutation).
- **Workload Identity** — *trust topology only* is documented here (one
  federation per AKS cluster, scoped by tenant/cluster). The concrete
  federation-credential subject pattern
  (`system:serviceaccount:<ns>:<sa>`) and the AKS OIDC issuer URL are
  captured in Stage 04 (AKS lifecycle) and applied per-app SA in Stage 07.

### Egress governance

- **NetworkPolicy default** for every namespace: deny egress to RFC1918 +
  internet; require explicit allow rules. For the **`demo` profile**
  (no Azure Firewall) the cluster uses **Cilium FQDN-aware
  `CiliumNetworkPolicy`** (since plain `NetworkPolicy` cannot do
  FQDN-matching). Default Cilium dataplane is installed in Stage 04.
- **Exception workflow**: request → security review → time-bounded firewall
  rule + NetworkPolicy → audit log entry. Documented in
  `docs/runbooks/egress-exception.md`. The exception PR-creation surface
  is wrapped by a Backstage scaffolder template in Stage 10
  (`request-egress-exception`).

## Scope (out)

- Workload VNets in landing-zone subscriptions (provisioned via vending,
  Stage 05).
- Service-mesh-based service-to-service auth (deferred — see ADR-0004).

## Deliverables

- `infrastructure/terraform/connectivity/` — hub VNet, Firewall, NAT GW,
  Private DNS zones, UDRs, peering placeholders.
- `infrastructure/terraform/identity/` — Entra groups, PIM policies, custom
  roles, RBAC assignments at subscription/resource-group scope.
- `policies/azure/firewall/allowlist.json` — curated FQDN allowlist.
- `docs/runbooks/egress-exception.md`.
- `docs/adr/0029-custom-roles.md`.

## Dependencies

- Stage 02 (subscription baseline and inherited ALZ policy readiness).

## Decisions / ADRs

- **ADR-0030** Hub-and-spoke (not Virtual WAN) for MVP; revisit when global
  routing / many regions emerges.
- **ADR-0031** Default-deny egress + FQDN allowlist + exception workflow.
  Prod/nonprod use Azure Firewall Premium FQDN filtering; `demo` uses
  in-cluster Cilium FQDN-aware policies only.
- **ADR-0029** Custom RBAC roles + group-only assignments.
- **ADR-0049** DDoS protection posture — Basic at MVP; trigger Network
  Protection per public tier-0 workload.

## Technologies

| Concern | Choice |
|---------|--------|
| Hub topology | Hub-and-spoke |
| Egress (prod/nonprod) | Azure Firewall Premium |
| Egress (demo) | NAT Gateway |
| DNS | Azure Private DNS zones, linked per VNet |
| Identity | Entra ID + PIM + custom RBAC roles |

## Acceptance criteria

1. New workload spokes peer to the hub via Terraform module with one variable.
2. From an AKS pod in `prod`/`nonprod`, only allowlisted FQDNs are reachable
   via Firewall; everything else is blocked with an Azure Monitor alert.
3. From an AKS pod in `demo`, only Cilium-NetworkPolicy-allowlisted FQDNs
   are reachable (NAT Gateway has no Azure-layer FQDN enforcement; this is
   the documented limit of the demo profile).
4. Every PaaS service has a Private DNS zone resolvable from the hub and
   spokes; Azure Monitor data flows through AMPLS without traversing the
   public internet.
5. All RBAC created by this repo at subscription/resource-group scope is via
   groups; user-direct assignments fail a periodic audit query. Any MG-scope
   assignment is handled by the external ALZ owner.
6. PIM activation produces an Azure Monitor alert (Sentinel routing added
   later if Sentinel is triggered — ADR-0046 / Stage 13).
7. Stage 01 Phase-2 retrofit complete: state account + seed KV are
   private-endpoint-only.

## Risks

- **Firewall allowlist drift** as new tools appear → quarterly review +
  exception expiry alerts.
- **Private DNS forwarding edge cases** with VPN/ExpressRoute → documented but
  out of MVP scope.
- **Group sprawl** → naming convention + automated cleanup of unused groups.
