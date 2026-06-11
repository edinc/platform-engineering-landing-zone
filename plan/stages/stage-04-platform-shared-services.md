# Stage 04 — Platform shared services

## Goal

Provision the core compute and data services that every subsequent stage and
every workload depends on, with DR designed in from the start.

## Scope (in)

In the `platform` subscription:

### AKS (one cluster per environment for MVP)

- Private cluster, Azure CNI **Overlay + Cilium dataplane**.
- Azure RBAC enabled, local accounts **disabled**, Entra integration.
- **System** node pool (3 nodes, AZ-spread, taint `CriticalAddonsOnly`) +
  **default user** pool.
- **AKS Node Auto-Provisioning (NAP)** — Microsoft-managed, built on
  Karpenter — for elastic user pools (default for `nonprod`/`prod`).
- **AKS Backup** enabled (Azure Backup vault, daily, geo-redundant). Scope
  is Kubernetes resources + persistent volumes; cluster control-plane is
  redeployed from Terraform on DR (Stage 12).
- **Planned Maintenance** (auto-upgrade channel `stable`; node OS channel
  `NodeImage`).
- **Workload Identity** + OIDC issuer enabled. The cluster's OIDC issuer
  URL is published to the platform's `outputs` for Stage 07 federated
  credential bindings.
- **Pod Security Admission** baseline at cluster, `restricted` per namespace
  policy (enforced in Stage 07 Kyverno layer).
- **Defender for Containers** profile enabled.
- **Private API server access** — cluster is fully private; the API server
  is reachable via Private Endpoint into the hub `private-endpoints`
  subnet. Operators reach it via Azure Bastion in the hub or a corporate
  VPN/ExpressRoute connection. (Note: AKS
  `api_server_authorized_ip_ranges` is silently a no-op on private
  clusters and is **not** set.)
- **API server VNet integration** (preview/GA per region availability)
  enabled where GA, for stable private-endpoint behaviour.

### `platform-cluster-state` GitOps repo bootstrap

- Create the separate Flux-watched repo `platform-cluster-state` declared
  in `plan.md` §8 / ADR-0013, with the initial directory layout
  (`clusters/_base/`, `clusters/overlays/{demo,nonprod,prod}/`, `tenants/`,
  `README.md`, branch protection, CODEOWNERS). This is the **first
  deliverable** of this stage; subsequent stages (05, 06, 07, 09, 11)
  write into it. A separate Terraform composition
  (`infrastructure/terraform/cluster-state-repo/`) using the GitHub
  provider creates and configures the repo. The Stage-05 GitHub App
  (`platform-vending-bot`) is the canonical writer.

### ACR (Premium)

- Geo-replication: primary + DR region (single login server; failover is
  DNS-routed, not a separate endpoint — see Stage 12).
- Private endpoint; public network access disabled.
- Azure trusted-service bypass enabled for registry control-plane operations such
  as `az acr import`; registry data-plane access still uses Private Link.
- **ACR Artifact Cache** rules for unauthenticated supported sources such as
  `mcr.microsoft.com` and `ghcr.io`. Docker Hub cache rules require a credential
  set in current ACR behaviour, so they are not enabled by default. `quay.io` is
  **not** a supported source — pulls from quay use the `az acr import` workflow
  in `workflows/import-quay.yml`.
- Retention policy: untagged manifests 14d; tag locks for promoted prod tags.
- **ACR Tasks** for base-image rebuilds run on a **VNet-injected dedicated
  agent pool** (required because ACR public access is disabled).

### Key Vault

- RBAC mode, Private Link, purge protection on, soft-delete 90d.
- Per-environment KV. Bootstrap KV (Stage 01) remains separate.
- For environments hosting Postgres CMK on HA clusters, **KV Premium SKU**
  with **availability-zone-redundant keys** so KV outage in one zone does
  not orphan the PG instance.

### Azure Database for PostgreSQL Flexible Server

- HA (zone-redundant) for `prod`, ZRS storage; single-zone for `nonprod`/`demo`.
- Customer-managed key from per-env KV (KV RPO must be ≤ PG RPO; cross-KV
  CMK replication / paired-vault backup documented in
  `docs/runbooks/dr-matrix.md`).
- Private networking: **delegated subnet** model (recommended by
  Microsoft for HA + Private DNS zone integration); Private Endpoint
  model documented as alternative.
- PITR retention 35 days; geo-redundant backup for `prod`.
- Database `backstage` provisioned for Stage 09.

### Service Bus (platform-internal eventing — ADR-0032)

- **Service Bus namespace** `sb-pe-<env>-<region>` (Premium for enabled
  environments so Private Endpoint is available), public access disabled, RBAC
  mode. Workload teams declare topics/queues via ASO v2 (Stage 07 curated CRD
  allowlist).

### Ingress

- **ingress-nginx** as in-cluster controller (default for MVP per ADR-0003).
- **Internal Load Balancer** for ingress-nginx (`service.beta.kubernetes.io/
  azure-load-balancer-internal: "true"`) bound to a **Private Link
  Service** (PLS) which Front Door consumes as its private origin.
- **Azure Front Door Premium** at the edge for public properties, with
  Private Link origin to the cluster's PLS endpoint.
- WAF policy attached to Front Door.
- Region note: Front Door Private Link origins are region-restricted;
  the chosen primary region must be in the supported list (documented in
  `docs/runbooks/region-matrix.md`).

### ACA platform substrate (foundation for Stage 11 ACA golden path)

- **Azure Container Apps managed environment** (`cae-pe-<env>-<region>`):
  VNet-injected internal mode, Log Analytics workspace shared with AKS,
  Workload Profiles (Consumption + 1 Dedicated profile for prod-tier
  ACA apps), zone-redundant where supported.
- ACA environment is **diagnostic-settings-attached** to the central LA
  workspace and routes through Front Door Premium via Private Link to
  the env's internal endpoint.
- The ACA managed environment exists for Stage 11 Template 2 to deploy
  into; no ACA apps deployed here.

### DR design (documented now, exercised in Stage 12)

- RTO/RPO matrix in `docs/runbooks/dr-matrix.md`:

  | Tier | Component | RTO | RPO |
  |------|-----------|-----|-----|
  | Critical | Postgres (Backstage + platform) | 1h | 5min (PITR + geo-backup) |
  | Critical | ACR | 1h | 0 (geo-rep) |
  | Critical | KV | 1h | 24h (soft-delete + replica) |
  | Important | AKS cluster | 4h | 24h (AKS Backup + IaC redeploy) |
  | Important | Terraform state | 1h | 1h (GRS + versioning) |
  | Standard | Workload PVCs | 8h | 24h (Azure Backup for AKS) |

## Scope (out)

- In-cluster GitOps + add-ons (Stage 07).
- Backstage application itself (Stage 09).
- Subscription vending (Stage 05).

## Deliverables

- `infrastructure/terraform/platform/`
  - `aks.tf`, `acr.tf`, `key-vault.tf`, `postgres.tf`, `service-bus.tf`,
    `ingress.tf`, `front-door.tf`, `aca-environment.tf`.
- `infrastructure/terraform/_modules/`
  - `aks-cluster/`, `acr-with-cache/`, `keyvault-rbac/`, `pg-flexible/`,
    `front-door-with-pl-origin/`, `service-bus/`, `aca-environment/`.
- `infrastructure/terraform/cluster-state-repo/` — Terraform composition
  using the GitHub provider that creates the **`platform-cluster-state`**
  repository, applies branch protection, CODEOWNERS, and seeds the
  `clusters/_base/`, `clusters/overlays/`, `tenants/` skeleton.
- `workflows/import-quay.yml` — `az acr import` wrapper for quay.io
  sources (since Artifact Cache does not support quay).
- `docs/runbooks/dr-matrix.md` — RTO/RPO per tier.
- `docs/runbooks/aks-baseline.md` — runbook for cluster operations (upgrade
  rings, node-pool changes, image-cleaner schedule).
- `docs/runbooks/region-matrix.md` — Front Door PE + AKS API VNet
  integration + ACA region constraints.

## Dependencies

- Stage 02 (subscription baseline and inherited ALZ policy readiness).
- Stage 03 (hub, Private DNS, egress).

## Decisions / ADRs

- **ADR-0003** ingress = ingress-nginx (internal LB + Private Link Service)
  + Front Door Premium at edge.
- **ADR-0009** AKS dataplane = Cilium.
- **ADR-0010** AKS Node Auto-Provisioning (NAP) — Microsoft-managed,
  built on Karpenter.
- **ADR-0012** Backstage hosting = in-cluster on AKS via Helm + Flux.
- **ADR-0017** DR posture = active-passive across two paired regions.
- **ADR-0032** Eventing bus default = Azure Service Bus for platform-internal
  (namespace provisioned here); Event Grid is a workload concern.
- **ADR-0050** ACA managed environment is a platform shared service; ACA
  apps target it from Stage 11 Template 2.

## Technologies

| Concern | Choice |
|---------|--------|
| Cluster | AKS standard mode, private, Azure CNI Overlay + Cilium |
| Cluster scale-out | AKS NAP (managed; built on Karpenter) |
| Image registry | ACR Premium + Artifact Cache + geo-replication |
| Secrets | Key Vault RBAC mode (Premium + ZRS keys for HA-PG envs) |
| DB | PostgreSQL Flexible Server (HA, PITR, CMK, delegated subnet) |
| Eventing (platform-internal) | Azure Service Bus (PE) |
| In-cluster ingress | ingress-nginx (internal LB + Private Link Service) |
| Edge ingress | Azure Front Door Premium + WAF (PE origin) |
| Serverless containers substrate | ACA managed environment (VNet-injected) |
| Backup | Azure Backup for AKS (K8s + PVs), PG PITR, KV soft-delete, ACR geo-rep |

## Acceptance criteria

1. AKS cluster passes the AKS baseline checklist (private, RBAC, WI,
   PSA, Defender, Backup, planned-maintenance, image cleaner). API server
   is only reachable via Private Endpoint / Bastion / VPN.
2. ACR Artifact Cache is configured; a `kubectl run` from inside the
   cluster can pull a public image through ACR with no internet egress.
   `az acr import` workflow round-trips a quay.io image successfully.
3. Backstage's Postgres DB exists and is reachable only via Private Link;
   CMK rotation does not interrupt connectivity.
4. A Front-Door-fronted hello-world ingress works end-to-end with WAF
   in detection mode via the ingress-nginx Private Link Service origin.
5. The `platform-cluster-state` repo exists with the seed layout, branch
   protection, and CODEOWNERS; the Stage-05 GitHub App can push to it.
6. The ACA managed environment exists and a manual smoke-test ACA app
   reaches a healthy state behind Front Door.
7. The Service Bus namespace exists and ASO v2 in Stage 07 can create a
   topic inside it.
8. DR matrix exists; Stage 12 will validate it.

## Risks

- **Cilium add-on regressions** vs upstream → pinned add-on version, upgrade
  PR template.
- **AKS Backup limitations** for certain CSI drivers → documented per-driver
  support matrix.
- **ACR Artifact Cache** is preview in some regions → fallback to `az acr
  import` workflow; same workflow covers `quay.io` always.
- **Front Door + Private Link origin** has regional constraints → documented
  in `region-matrix.md`.
- **KV CMK loss → PG data inaccessible** → KV soft-delete + purge protection
  + paired-vault backup; KV RPO must match PG RPO.
- **ACA region churn** — managed environment features (workload profiles,
  zone redundancy) vary by region; region choice locked by Stage 11
  acceptance.
