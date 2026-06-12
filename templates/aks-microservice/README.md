# AKS microservice template

Stage 11 introduces the AKS microservice golden path. Stage 08 pre-seeds the
observability contract: this template must render `templates/_partials/slo.yaml`
and the KEDA partial so new services get SLOs, dashboards, alerts, and cost tags
without developer-authored monitoring configuration.
