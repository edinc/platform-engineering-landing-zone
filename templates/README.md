# Golden path templates

Backstage Software Templates begin in Stage 10 with platform onboarding flows.
Stage 08 adds reusable partials that every Stage 11 golden path must include so
services inherit SLOs, alert annotations, dashboards, KEDA scale-to-zero, and
cost tags by default.

| Template | Stage | Purpose |
| --- | --- | --- |
| [`onboard-team`](onboard-team/) | 10 | Creates a `TeamOnboardingRequest` PR for Entra, GitHub, namespace vending, ownership, and cost showback. |
| [`request-egress-exception`](request-egress-exception/) | 10 | Opens a time-boxed egress exception PR with firewall and Cilium policy drafts. |

| Partial | Purpose |
|---------|---------|
| [`_partials/slo.yaml`](_partials/slo.yaml) | Sloth SLO and burn-rate alert convention with required `runbook_url`. |
| [`_partials/slo-rule-group.tf.tmpl`](_partials/slo-rule-group.tf.tmpl) | Azure Managed Prometheus rule-group evaluator for generated SLO alerts. |
| [`_partials/keda-scaledobject.yaml`](_partials/keda-scaledobject.yaml) | Scale-to-zero pattern for queue/HTTP workers. |
