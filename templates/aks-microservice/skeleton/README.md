# ${{ values.componentTitle }}

Generated from the Stage 11 AKS microservice golden path.

| Field | Value |
| --- | --- |
| Team | `${{ values.teamName }}` |
| Product | `${{ values.productName }}` |
| Environment | `${{ values.environment }}` |
| Namespace | `${{ values.namespace }}` |
| Runtime | `${{ values.language }}` |
| Data classification | `${{ values.dataClassification }}` |
| On-call | `${{ values.onCallRotationId }}` |

## Local run

```bash
docker build -t ${{ values.componentId }}:dev .
docker run --rm -p ${{ values.port }}:${{ values.port }} ${{ values.componentId }}:dev
curl -fsS http://localhost:${{ values.port }}/healthz
```

## Delivery

`.github/workflows/ci.yml` calls the platform Stage 06 reusable workflows to:

1. build, scan, generate SBOMs, and sign the image;
2. package and sign the Helm chart;
3. publish TechDocs;
4. open a GitOps PR into `platform-cluster-state` for the vended namespace.

Promotion beyond the initial environment is intentionally platform-reviewed
until HelmRelease-aware promotion is implemented.
