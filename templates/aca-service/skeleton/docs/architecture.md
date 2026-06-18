# Architecture

`${{ values.componentId }}` runs as an Azure Container App in the existing Stage
04 managed environment.

```mermaid
flowchart LR
  developer[Developer] --> github[GitHub Actions]
  github --> acr[Platform ACR]
  github --> tf[Terraform azurerm_container_app]
  github --> aca[Azure Container Apps]
  aca --> appi[Application Insights]
```

Terraform owns the app resource and networking. The CI workflow verifies signed
image digests before using `az containerapp update` for deploy-only revisions.
