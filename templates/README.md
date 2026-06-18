# Golden path templates

Backstage Software Templates provide platform onboarding flows and developer
golden paths that create deployable workload repositories or reviewed namespace
vending PRs.

| Template | Purpose |
| --- | --- |
| [`onboard-team`](onboard-team/) | Creates a `TeamOnboardingRequest` PR for Entra, GitHub, namespace vending, ownership, and cost showback. |
| [`request-egress-exception`](request-egress-exception/) | Opens a time-boxed egress exception PR with firewall and Cilium policy drafts. |
| [`aks-workload-namespace`](aks-workload-namespace/) | Opens a reviewed namespace vending PR with quota, ownership, and Backstage `Resource` metadata. |
| [`aks-microservice`](aks-microservice/) | Creates an AKS microservice repository with CI, signed images, Helm, Flux, SLOs, TechDocs, and on-call metadata. |
| [`aca-service`](aca-service/) | Creates an Azure Container Apps service repository that targets the platform-managed ACA environment. |

| Partial | Purpose |
|---------|---------|
| [`_partials/catalog-info.yaml`](_partials/catalog-info.yaml) | Shared Backstage Component conventions for generated services. |
| [`_partials/devcontainer/`](_partials/devcontainer/) | Shared devcontainer baseline for generated repositories. |
| [`_partials/mkdocs.yml`](_partials/mkdocs.yml) | Shared TechDocs configuration. |
| [`_partials/renovate.json`](_partials/renovate.json) | Shared dependency update policy. |
| [`_partials/on-call-annotations.yaml`](_partials/on-call-annotations.yaml) | Shared on-call metadata annotations. |
| [`_partials/chart/templates/_helpers.tpl`](_partials/chart/templates/_helpers.tpl) | Shared Helm helper labels and naming. |
| [`_partials/slo.yaml`](_partials/slo.yaml) | Sloth SLO and burn-rate alert convention with required `runbook_url`. |
| [`_partials/slo-rule-group.tf.tmpl`](_partials/slo-rule-group.tf.tmpl) | Azure Managed Prometheus rule-group evaluator for generated SLO alerts. |
| [`_partials/keda-scaledobject.yaml`](_partials/keda-scaledobject.yaml) | Scale-to-zero pattern for queue/HTTP workers. |
