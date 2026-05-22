# Stage 09 — Backstage MVP

## Goal

Deploy Backstage as the developer portal — built and deployed by *this
platform's own supply chain* (Stage 06), running on the platform's AKS
cluster (Stage 04/07), authenticated with Entra ID, and surfacing the
catalog, Kubernetes view, GitHub workflows, TechDocs, and Cost Insights.

## Scope (in)

### Backstage application

- Backstage app scaffolded with `@backstage/create-app`, retained in
  `backstage/app/`.
- **Auth**: Entra ID OIDC provider with a **dynamic Entra group resolver**
  (groups → Backstage `Group` entities via Microsoft Graph) — *not*
  hard-coded group names, so onboarding (Stage 10) just adds an Entra
  group and Backstage picks it up.
- **Database**: managed PostgreSQL Flexible Server `backstage` DB (Stage 04).
  - Auth: **Entra ID passwordless authentication** (Postgres-EntraAD
    integration) is the **preferred** option — Backstage acquires a token
    via Workload Identity. Fallback: KV-stored, Renovate-rotated
    Postgres password injected via Secrets Store CSI.
- **TechDocs storage**: **Azure Blob storage account** + container
  `techdocs/`, Private Endpoint, RBAC for Backstage WI to read/write and
  for Stage 06 `techdocs-publish.yml` workflow to write. Provisioned by
  Terraform in `infrastructure/terraform/platform/techdocs.tf` (this
  stage; could also live with Stage 04 — placed here for ownership
  clarity).
- **Hosting**: in-cluster on AKS via Helm chart `backstage/deploy/` deployed
  by Flux from `platform-cluster-state/clusters/_base/backstage/`.
- **Image**: built and signed by Stage-06 reusable workflows; promoted via
  PR-promotion to nonprod and prod.

### Catalog ingestion

- **GitHub Discovery** processor scanning the platform's GitHub org for
  `catalog-info.yaml`.
- **Custom Azure processor** (deferred to Stage 13) — for now ingest Azure
  resources via TechDocs links + annotations on Components.
- **Catalog entity governance**: Lifecycle (`experimental`/`production`/
  `deprecated`), Ownership (must reference an Entra group), Annotations
  (`backstage.io/source-location`, `backstage.io/kubernetes-id`,
  `dev.azure.com/...` for ADO co-existence).
- **Catalog reconciliation** job (custom): compares Backstage Components
  against vended namespaces (Stage 05) and reports drift.

### Plugins (community only at MVP; no custom plugins)

- `@backstage/plugin-kubernetes` (multi-cluster). **Auth pattern**: the
  Backstage backend pod runs with **Workload Identity** federated to a
  per-cluster managed identity granted **AKS Cluster User role** + a
  custom AKS Cluster RBAC `ClusterRole` for read of Pods/Deployments/
  Services/Ingresses. The plugin uses the WI-issued AAD token to
  authenticate to each AKS API. **No long-lived kubeconfig** is stored
  in Backstage's database.
- `@backstage/plugin-github-actions`.
- `@backstage-community/plugin-flux` for GitOps view.
- `@backstage/plugin-techdocs` + Azure Blob TechDocs publisher (storage
  provisioned above; the **Stage 06 `techdocs-publish.yml`** reusable
  workflow does the build/publish per repo).
- `@backstage/plugin-scaffolder` (templates added in Stage 11).
- `@backstage-community/plugin-cost-insights` with Azure Cost Management
  adapter (community plugin; in-house wrapper scaffold ready in
  `backstage/plugins/cost-insights-azure/` as fallback if it regresses).
- `@backstage/plugin-permission-backend` + permission policies (for RBAC).

### Catalog reconciliation job

- A **CronJob** in `clusters/_base/backstage/catalog-reconciler/` runs
  every 15 min:
  - Queries the Backstage catalog API (using WI-authenticated SA).
  - Queries the AKS API for namespaces with `platform.example.io/team` label
    and the GH org for repos with `catalog-info.yaml`.
  - Reports drift to `#platform-drift` Teams channel + writes a structured
    log line consumed by Stage-08 dashboards.

### Backstage RBAC

- **Backstage Permission Framework** with a policy file that resolves
  permissions **dynamically** from Entra group claims at request time
  (rather than hard-coded group names):
  - Members of `pe-platform-admins` → all permissions.
  - Members of `pe-platform-operators` → catalog write, scaffolder execute,
    K8s view.
  - Members of any `pe-app-team-*` → catalog read all, catalog write own,
    scaffolder execute, K8s view own namespaces.
  - All others → catalog read only.
- Group membership is read at session-token issue time; the policy
  resolves group → permission via a config map (not hard-coded) so
  Stage 10 onboarding doesn't require Backstage code changes.

### Operational

- Backstage deployment is **HA** (≥ 2 replicas) for nonprod/prod.
- Postgres failover documented (PITR + geo-restore for `prod`).
- Backstage SLO published in Stage-08 dashboard.

## Scope (out)

- Software templates (Stage 11).
- Custom plugins, including "Platform Console" (Stage 13).
- ADO co-existence plugin (Stage 13 if needed).

## Deliverables

- `backstage/app/` — Backstage application source.
- `backstage/deploy/` — Helm chart values + manifests rendered.
- `backstage/plugins/cost-insights-azure/` — fallback in-house Cost
  Insights adapter scaffold (kept on the shelf, not deployed unless the
  community plugin regresses).
- `clusters/_base/backstage/catalog-reconciler/` — CronJob spec for
  Backstage ↔ vended-namespace drift detection.
- `infrastructure/terraform/platform/techdocs.tf` — Blob storage account
  + PE + RBAC for TechDocs.
- `policies/backstage/permissions.ts` — RBAC policy file with dynamic
  Entra group resolver.
- `docs/runbooks/backstage-ops.md` — operator runbook (upgrade, restore,
  TechDocs publish issues, WI K8s plugin troubleshooting, Postgres-EntraAD
  token-refresh issues).
- `docs/adr/0020-build-vs-buy.md` — current decision = Backstage; Stage-13
  re-evaluation trigger documented.
- `docs/adr/0042-techdocs-storage.md` — Azure Blob with PE.
- `docs/adr/0052-backstage-postgres-auth.md` — Entra AD preferred, KV
  password fallback.

## Dependencies

- Stage 04 (Postgres, AKS, ACR), Stage 06 (CI/CD), Stage 07 (Flux, OTel,
  cert-manager, ingress), Stage 08 (observability primitives).

## Decisions / ADRs

- **ADR-0020** Backstage vs Port/Humanitec/Cortex — Backstage chosen; TCO
  re-evaluation at Stage 13.
- **ADR-0041** Backstage RBAC via Permission Framework, group-mapped from
  Entra ID via dynamic resolver.
- **ADR-0042** TechDocs storage = Azure Blob with Private Endpoint
  (managed by platform).
- **ADR-0052** Backstage Postgres auth = Entra AD passwordless via WI
  (preferred); KV-stored rotated password (fallback).

## Technologies

| Concern | Choice |
|---------|--------|
| App framework | Backstage |
| Auth | Entra ID OIDC |
| DB | Postgres Flexible (shared platform PG) |
| Hosting | AKS in-cluster (Helm + Flux) |
| TechDocs storage | Azure Blob |
| RBAC | Backstage Permission Framework |
| Plugins | Community-only at MVP |

## Acceptance criteria

1. `backstage.<env>.platform.<root>` is reachable, authenticates via Entra,
   and lists ≥ 10 catalog entities discovered from GitHub.
2. The Kubernetes plugin shows pods for a sample Component using WI auth
   (no cluster admin kubeconfig in Backstage's database).
3. Cost Insights tab shows real Azure Cost Management data with team
   breakdown.
4. Permission policy denies a non-admin user from deleting a Component;
   audit log captures the attempt.
5. Backstage HA: rolling restart of one replica does not break the UI.
6. Backstage SLO dashboard is green and published in Managed Grafana.

## Risks

- **Backstage upgrade cadence** (every 2 weeks upstream) → Renovate auto-PRs +
  test harness; quarterly major-version review.
- **Custom plugins drift** → forbidden at MVP; defer until justified.
- **Cost Insights Azure adapter** is community-maintained → in-house wrapper
  ready as fallback if it regresses.
- **TechDocs build times** → use the `recommended` flow with publisher mode
  (build in CI, not at view time).
