# AKS microservice template

Opens a platform-reviewed request to create a team-owned microservice repository
for AKS workloads that need the Kubernetes platform substrate.

Generated repositories include:

- language scaffold for Node.js TypeScript, Python, or .NET;
- `.devcontainer/`, README, TechDocs, Renovate, and Backstage catalog metadata;
- Helm chart with HPA, PDB, NetworkPolicy, ServiceMonitor, optional ingress, and
  KEDA scale-to-zero support;
- DNS egress plus default-deny CIDR egress; FQDN egress exceptions remain a
  platform-reviewed workflow;
- Sloth `slo.yaml` and runbook/dashboard annotations;
- GitHub Actions wired to reusable build/sign/SBOM, Helm publish,
  GitOps PR push, promotion, and TechDocs workflows.
