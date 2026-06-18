# ${{ values.componentTitle }}

Generated from the Azure Container Apps golden path.

| Field | Value |
| --- | --- |
| Team | `${{ values.teamName }}` |
| Product | `${{ values.productName }}` |
| Environment | `${{ values.environment }}` |
| ACA environment | Protected `PLATFORM_ACA_ENVIRONMENT_ID` GitHub Environment variable |
| Runtime | `${{ values.language }}` |
| Scale rule | `${{ values.scaleRule }}` |
| On-call | `${{ values.onCallRotationId }}` |

## Local run

```bash
docker build -t ${{ values.componentId }}:dev .
docker run --rm -p ${{ values.port }}:${{ values.port }} ${{ values.componentId }}:dev
curl -fsS http://localhost:${{ values.port }}/healthz
```

## Deployment model

Terraform in `infra/` owns the `azurerm_container_app` resource in the existing
platform-managed environment. Application image updates are deploy operations:
the workflow verifies the signed digest with cosign, then runs
`az containerapp update --image <digest>`.

The target ACA managed environment, resource group, region, ACR ID, and ACR
login server come from protected GitHub Environment variables, not template user
input.

Terraform state is stored in the protected remote state account under
`golden-paths/aca/${{ values.environment }}/${{ values.componentId }}.tfstate`.
