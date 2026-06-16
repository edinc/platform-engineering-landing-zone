# Backstage

Stage 09 introduces the Backstage MVP:

- `app/` contains the configuration-first Backstage application package, catalog
  seed, Docker build contract, and local validation script.
- `deploy/` contains the Helm chart published by the Stage 06 chart workflow and
  consumed by Flux from ACR as an OCI chart.
- `plugins/cost-insights-azure/` contains the fallback Azure Cost Management
  adapter scaffold. The MVP deploys the community Cost Insights plugin first;
  this scaffold stays inactive unless ADR-0020 is revisited.

Runtime secrets, tenant IDs, image digests, and managed identity identifiers are
supplied through Terraform/Flux post-build substitution and Kubernetes secrets.
Do not commit environment-specific Backstage configuration or kubeconfigs.
