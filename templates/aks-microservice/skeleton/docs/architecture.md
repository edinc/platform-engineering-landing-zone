# Architecture

`${{ values.componentId }}` runs in the vended `${{ values.namespace }}`
namespace on the platform AKS cluster.

```mermaid
flowchart LR
  developer[Developer] --> github[GitHub Actions]
  github --> acr[Platform ACR]
  github --> gitops[platform-cluster-state PR]
  gitops --> flux[Flux]
  flux --> aks[AKS namespace ${{ values.namespace }}]
  aks --> prometheus[Managed Prometheus]
  prometheus --> grafana[Managed Grafana]
```

Flux owns runtime state. GitHub Actions only publishes signed artifacts and opens
GitOps PRs.
