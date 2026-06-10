# Stage 08 — Observability, SRE, FinOps

## Goal

Make observability, SLOs, alerting, and cost allocation **first-class
primitives** that every golden path inherits — before any templates ship.

## Scope (in)

### Observability pipeline

- OTel collector pipeline finalised (started in Stage 07) with conventions
  for resource attributes: `service.name`, `service.namespace`, `team`,
  `product`, `env`, `version`.
- Structured-log convention (JSON, ECS-aligned) + per-language libraries
  (Pino for Node, structlog for Python, Serilog for .NET) referenced from
  golden-path templates.
- **Trace sampling** policy: 100% in dev, head-based 10% in nonprod,
  tail-based + error-priority sampling in prod.

### SLO toolkit

- **Sloth** for declarative SLOs as code (ADR-0038 resolves to **Sloth**
  over OpenSLO — Sloth is mature, opinionated, and emits standard
  Prometheus recording + alerting rules with multi-window multi-burn-rate
  alerts).
- Per-service `slo.yaml` convention referenced by golden paths.
- Auto-generated Prometheus alerting rules + Grafana dashboard from the
  Sloth CRD.
- SLO + current burn-rate are surfaced in **Backstage** (Stage 09) via the
  Backstage Prometheus / dashboards plugin; the *measurement surface* is
  this stage, the *Backstage UI surface* is Stage 09.

### Alerting & on-call

- **Action Groups** + native PagerDuty connector (Action Group
  `PagerDuty` action type, not custom webhook) for prod/nonprod; Teams
  webhook for `demo`.
- Severity tiers: SEV1 (page), SEV2 (ticket), SEV3 (digest).
- **Runbook URL convention** — every alert carries `runbook_url` annotation;
  CI lints alert rules to ensure presence.
- **Status page** — **Upptime** (GitHub-Pages-based, low-ops) for MVP;
  Cachet is documented as an alternative but is in **maintenance mode
  upstream**, so it is the secondary choice not the primary.

### FinOps

- Cost Management exports → existing ALZ-owned ADLS Gen2 container (export
  configured in Stage 02) consumed by:
  - **Backstage Cost Insights** plugin (Stage 09), with a documented
    fallback in-house adapter in `backstage/plugins/cost-insights-azure/`
    if the community adapter regresses.
  - A nightly Function App that allocates costs by `costCenter` + `team` +
    `product` tags and publishes per-team showback CSVs.
- **AKS NAP** (Stage 04) drives bin-packing efficiency.
- **KEDA scale-to-zero patterns** — KEDA is *installed* in Stage 07; this
  stage owns the **patterns** (ScaledObject templates referenced by
  golden paths, scale-to-zero validation harness).
- **Idle/rightsizing detection**: a CronJob runs **VPA Recommender**
  (and optionally **Goldilocks** for friendlier reports) weekly and
  opens GitHub Issues for over-provisioned workloads.
- **Environment TTL**: `demo` environments auto-decommission after 30d via
  a **scheduled GitHub Actions workflow** (`workflows/ttl-sweep.yml`)
  that checks the `expiresOn` tag and opens a decommission PR. (Azure
  Automation considered and rejected — adds another service to operate.)

### Platform SLOs (initial targets)

| SLO | Target | Measurement |
|-----|--------|-------------|
| Backstage availability | ≥ 99.5% | Front Door synthetic + ingress 5xx ratio |
| Flux reconciliation p95 latency | < 5 min | `gotk_reconcile_duration` histogram |
| Cluster API availability | ≥ 99.9% | Azure Monitor + AMA AKS metrics |
| Golden-path success rate | ≥ 95% | Scaffolder task `success/total` ratio + repo's first-run CI green ratio (≥ 95% over rolling 30d) |
| Vending PR → merge latency p95 | < 1 working day | GH Actions / API stats |
| Time-to-restore (Postgres PITR) | ≤ 60 min | Drill measured in Stage 12 |
| Signature-verify mean overhead | < 200 ms | Kyverno admission timing via `kyverno_admission_review_duration_seconds` |

## Scope (out)

- Backstage application itself (Stage 09).
- Custom dashboards beyond seeded set (per-team work in Stage 10/11).

## Deliverables

- `clusters/_base/observability/` — OTel, Managed Prom DCR, Grafana
  dashboards-as-code, default Sloth `PrometheusRule`s.
- `templates/_partials/slo.yaml` — SLO template included by golden paths.
- `infrastructure/terraform/_modules/cost-allocator/` — Function App + ADLS
  consumer + output bindings.
- `docs/runbooks/sre/` — alert response runbooks (one per critical alert).
- `docs/runbooks/platform-slos.md` — SLO definitions + monthly review cadence.
- `docs/adr/0037-otel-conventions.md`.
- `docs/adr/0038-slo-tooling.md` — Sloth vs OpenSLO choice.

## Dependencies

- Stage 07 (Managed Prom/Grafana, OTel).
- Stage 02 (Cost Management export configuration to an existing container).

## Decisions / ADRs

- **ADR-0037** OTel resource attribute & log-field conventions.
- **ADR-0038** SLO tool = **Sloth** (resolved here; OpenSLO documented as
  alternative — chosen for maturity + native Prom multi-burn-rate alerts).
- **ADR-0039** On-call tool = PagerDuty (native Azure Monitor Action Group
  connector) for prod/nonprod, Teams for demo.
- **ADR-0040** Status page = **Upptime** for MVP (low-ops, GH Pages);
  Cachet documented as alternative but flagged as upstream-maintenance.

## Technologies

| Concern | Choice |
|---------|--------|
| Metrics | Managed Prometheus |
| Dashboards | Managed Grafana (dashboards-as-code) |
| Logs | Container Insights → Log Analytics |
| Traces | App Insights + OTel collector |
| SLO | Sloth |
| Alert routing | Action Groups + PagerDuty |
| Status page | Upptime (GH-Pages-hosted) |
| Cost allocation | Azure Cost Management exports + Function App |
| FinOps automation | AKS NAP, KEDA patterns, VPA Recommender / Goldilocks, GH Actions TTL sweep |

## Acceptance criteria

1. A new sample service deploys with a generated SLO + dashboard + alerts
   *without* the developer authoring any monitoring config.
2. Alert with no `runbook_url` annotation fails CI.
3. Cost showback CSV is produced nightly with team-level breakdown.
4. AKS NAP scales user pool from 0 → N → 0 in dev within expected windows.
5. A `demo` environment past `expiresOn` is auto-decommissioned by the
   scheduled GitHub Actions workflow with notice.
6. Platform SLOs are published in a Grafana dashboard fed by the platform's
   own metrics, with measurement definitions matching the table above.

## Risks

- **Dashboard sprawl** → "dashboards-as-code only" rule; CI rejects ad-hoc
  Grafana exports.
- **Alert fatigue** → SLO-burn-rate alerts only by default; raw resource
  alerts opt-in.
- **Cost allocation gaps** for shared services → un-tagged costs go to a
  `platform-overhead` bucket charged to a single cost center.
- **PagerDuty cost** → Teams fallback documented for `demo`/`nonprod`.
