# Platform SLOs

Stage 08 publishes the first platform SLO set. The measurement surface is
Managed Prometheus and Managed Grafana; Stage 09 surfaces the same data in
Backstage.

| SLO | Target | Measurement |
|-----|--------|-------------|
| Backstage availability | >= 99.5% | Front Door synthetic check and ingress 5xx ratio. |
| Flux reconciliation p95 latency | < 5 minutes | `gotk_reconcile_duration_seconds` histogram. |
| Cluster API availability | >= 99.9% | AKS API server metrics and Azure Monitor health. |
| Golden-path success rate | >= 95% | Scaffolder success ratio and first-run CI green ratio over 30 days. |
| Vending PR to merge latency p95 | < 1 working day | GitHub Actions and pull request timestamps. |
| Time to restore Postgres PITR | <= 60 minutes | Stage 12 restore drill measurement. |
| Signature-verify mean overhead | < 200 ms | `kyverno_admission_review_duration_seconds`. |

## Monthly review cadence

1. Export the previous calendar month from Grafana dashboard
   `grafana-dashboard-platform-slos`.
2. Record actual availability, latency, and burn-rate outcomes in the platform
   operating review.
3. Create one improvement issue for every missed SLO or exhausted error budget.
4. Review alert volume and suppressions to keep SEV1/SEV2 pages actionable.
5. Check unallocated FinOps spend and reconcile it to `platform-overhead`.

## Alert requirements

Every alert generated from Sloth or committed as a `PrometheusRule` must include:

- `severity` label: `sev1`, `sev2`, or `sev3`.
- `runbook_url` annotation pointing to `docs/runbooks/sre/`.
- A dashboard link when a Grafana panel exists.

`make alert-runbook-lint` enforces the `runbook_url` requirement.
