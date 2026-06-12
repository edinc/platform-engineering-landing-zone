# Golden path templates

Backstage Software Templates are introduced in Stage 11. Stage 08 adds reusable
partials that every golden path must include so services inherit SLOs, alert
annotations, dashboards, KEDA scale-to-zero, and cost tags by default.

| Partial | Purpose |
|---------|---------|
| [`_partials/slo.yaml`](_partials/slo.yaml) | Sloth SLO and burn-rate alert convention with required `runbook_url`. |
| [`_partials/slo-rule-group.tf.tmpl`](_partials/slo-rule-group.tf.tmpl) | Azure Managed Prometheus rule-group evaluator for generated SLO alerts. |
| [`_partials/keda-scaledobject.yaml`](_partials/keda-scaledobject.yaml) | Scale-to-zero pattern for queue/HTTP workers. |
