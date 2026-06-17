# Azure Container Apps service template

Opens a platform-reviewed request to create a team-owned service repository for
Azure Container Apps workloads that do not need Kubernetes control-plane
features.

Generated repositories include:

- language scaffold for Node.js TypeScript, Python, or .NET;
- `.devcontainer/`, README, TechDocs, Renovate, and Backstage catalog metadata;
- Terraform for an `azurerm_container_app` targeting the Stage 04 managed
  environment;
- GitHub Actions wired to Stage 06 build/sign/SBOM and TechDocs workflows plus a
  signed digest verification gate before `az containerapp update`;
- Application Insights KQL SLO pack for availability, failure ratio, and
  latency.
