# Stage 12 — DR drills & incident workflow

## Goal

Prove the DR design from Stage 04 actually works, and operationalise on-call,
incident response, runbooks, status page, and post-mortems.

## Scope (in)

### DR drills (quarterly, calendared)

Each drill validates the **RTO/RPO matrix** from Stage 04. The first drill
records baselines; subsequent drills assert each target.

- **Postgres PITR restore** of the Backstage database to a point 15 min ago;
  verify Backstage catalog integrity. Target RTO ≤ 60 min.
- **AKS Backup restore** of a sample team's **Kubernetes resources + PVs**
  into a fresh namespace (AKS Backup does **not** restore the cluster
  control plane — that is redeployed from Terraform separately).
- **Key Vault recovery** from soft-delete plus paired-vault restore in the
  secondary region. Verify Workload Identity continuity post-restore.
  (Note: "geo-replicated KV" is a misnomer — Azure KV does not transparently
  replicate; this drill covers backup/restore + paired-vault re-pointing.)
- **ACR geo-replication failover**: ACR Premium uses a **single login
  server with regional replicas**; failover means **disabling the
  primary replica + verifying pulls route to the secondary replica via
  ACR's traffic management** (not a separate endpoint). Verify
  Private DNS resolution still resolves to the in-region private
  endpoint of the surviving replica.
- **Terraform state recovery** from versioned + GRS-replicated state account.
- **Cluster redeploy from IaC**: tear down `demo` cluster, re-apply Stage 04
  in < 2h. (Separate drill from the AKS Backup PV-restore drill, which
  uses an existing cluster.)

### Incident workflow

- **Severity matrix** (SEV1/2/3 with response-time and comms expectations).
- **Incident channel template** (Teams) auto-created on PagerDuty SEV1 via
  the **native PagerDuty ↔ Microsoft Teams connector** (no Logic App,
  no custom webhook).
- **Incident commander handoff** template.
- **Status page** (Upptime, deployed in Stage 08; Cachet as alternative
  but in maintenance) drives external comms; SEV1 triggers an auto-update
  via PagerDuty webhook → Upptime / Cachet API.
- **Runbook catalog** — every alert has a `runbook_url` (Stage 08 lint) and
  the destination MD exists in `docs/runbooks/sre/`.
- **Post-mortem template** with two-tier handling:
  - **Sanitised post-mortem** in `docs/postmortems/` (PII-scrubbed).
  - **Raw timeline + logs** in a restricted access location (e.g.,
    SharePoint with team-only ACL or Azure DevOps wiki — chosen per
    ADR-0046).
- **Blameless review** cadence: weekly SLO/burn-rate health check;
  **monthly** post-mortem review (separate forums).

### Game-days (chaos)

Two layers, deliberately separated:

- **Pod-level chaos** (lightweight, `kubectl`-driven via Chaos Mesh CRs or
  raw `kubectl delete pod` scripts):
  - Kill a Backstage pod.
  - Kill a cert-manager pod and observe issuer failure mode.
  - Drop a workload's NetworkPolicy and observe alerting.
- **Infrastructure-level chaos** via **Azure Chaos Studio**:
  - Kill a node in the user pool.
  - Inject AKS API throttling.
  - Drop hub Firewall rule and observe egress blast radius.

Each experiment paired with an explicit expected behaviour and a real one.

### Platform health scorecard

- Weekly scorecard (Grafana dashboard + automated comment on the platform
  repo's Discussions tab) reporting against Stage-08 SLOs.

## Scope (out)

- Multi-region active-active (Stage 13).
- Sentinel deployment (deferred unless compliance scope expands).

## Deliverables

- `docs/runbooks/dr-drills/` — one MD per drill with checklist + expected
  outcomes.
- `docs/runbooks/incident-response.md` — sev matrix, IC handoff, comms tree.
- `docs/templates/post-mortem.md`.
- `infrastructure/terraform/_modules/chaos-studio/` — chaos experiments as
  Terraform.
- `clusters/_base/observability/platform-scorecard.json` — Grafana dashboard.
- `docs/adr/0045-game-day-cadence.md`.

## Dependencies

- Stage 04 (DR design), Stage 06 (`techdocs-publish.yml` + reusable
  promote/build workflows for post-mortem doc publishing), Stage 07
  (cluster ops), Stage 08 (SLOs + alerting + status page + Sloth-resolved
  format), Stage 09 (Backstage with runbook surface), Stage 11 (golden
  paths must exist for cross-team incident-readiness validation).

## Decisions / ADRs

- **ADR-0045** Game-day cadence + scope (platform-only at MVP; tenants opt-in
  later). Splits pod-level (kubectl/Chaos Mesh) from infra-level (Chaos
  Studio).
- **ADR-0046** Post-mortem retention + PII handling — two-tier
  (sanitised-in-repo, raw-in-restricted-system).

## Technologies

| Concern | Choice |
|---------|--------|
| DR mechanics | Azure Backup for AKS (K8s + PVs), Postgres PITR + geo-restore, ACR geo-replication failover (single login server), KV soft-delete + paired-vault restore |
| Pod-level chaos | Chaos Mesh / kubectl scripts |
| Infra-level chaos | Azure Chaos Studio |
| Incident comms | PagerDuty + native Teams connector + Upptime |
| Health scorecard | Managed Grafana |

## Acceptance criteria

1. **First DR drill in `nonprod`** records baselines for every component
   in the RTO/RPO matrix; subsequent drills assert against the recorded
   baseline + Stage-04 targets.
2. A SEV1 alert produces: page within 5 min, incident channel within 2 min,
   IC assignment within 10 min, status-page entry within 15 min.
3. Every active alert has a working runbook link.
4. A post-mortem is published within 5 working days of any SEV1 (sanitised
   form in repo; raw form in restricted system).
5. Quarterly game-day report includes at least one identified-and-fixed
   resilience gap, with at least one pod-level and one infra-level
   experiment.

## Risks

- **Drill fatigue** → rotate ownership; mix automated + manual drills.
- **Chaos blast radius** → start in `demo`, then `nonprod`, never `prod`
  without explicit ADR amendment.
- **PII in post-mortems** → template enforces scrubbing checklist.
