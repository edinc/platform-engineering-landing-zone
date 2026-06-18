# Runbook

## Health check

```bash
az containerapp show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name ca-${{ values.componentId }}-${{ values.environment }} \
  --query properties.runningStatus -o tsv
```

If the app is public, check the latest FQDN:

```bash
az containerapp show \
  --resource-group "$PLATFORM_RESOURCE_GROUP_NAME" \
  --name ca-${{ values.componentId }}-${{ values.environment }} \
  --query properties.configuration.ingress.fqdn -o tsv
```

## Alerts

KQL queries in `observability/app-insights-kql/` read Log Analytics structured
`http_request` console traces emitted by the generated service to define
availability, failure ratio, and latency SLOs. Alerts page
`${{ values.onCallRotationId }}`.
