# Azure Platform Engineering Landing Zone

Documentation for the Azure Platform Engineering Landing Zone: an opinionated,
secure, and compliant Internal Developer Platform (IDP) for an Azure tenant and
its subscriptions.

These pages are published to Backstage TechDocs from the platform repository.
The product roadmap lives in `plan/plan.md`, and stage-by-stage implementation
notes live in `plan/stages/`.

## What the platform provides

| Capability | Outcome |
| --- | --- |
| Azure foundation | Remote Terraform state, OIDC GitHub deployment identity, seed Key Vault, diagnostics, and break-glass monitoring. |
| Subscription baseline | Activity Log diagnostics, Defender for Cloud posture, budgets, cost exports, and policy validation. |
| Connectivity | Hub/spoke networking, Private DNS, Private Endpoints, and egress exception workflows. |
| Platform services | Private AKS, ACR, Key Vault, Service Bus, Container Apps environment, and optional Postgres/TechDocs/cost allocator. |
| GitOps platform | Flux, cert-manager, external-dns, External Secrets, CSI Key Vault provider, ASO, Kyverno, KEDA, and ingress-nginx. |
| Developer portal | Backstage with Entra auth, catalog, TechDocs, Kubernetes, Flux, GitHub Actions, Cost Insights, RBAC, and scaffolder templates. |
| Golden paths | AKS microservice, Azure Container Apps service, and AKS workload namespace templates with CI, signing, SBOMs, SLOs, docs, and ownership metadata. |

## Documentation map

- [Architecture](architecture/README.md) — reference architecture, component
  maps, and design notes.
- [Architecture decision records](adr/README.md) — accepted and proposed ADRs
  capturing the key platform decisions and their trade-offs.
- [Runbooks](runbooks/README.md) — operational procedures, incident response,
  and recovery steps for the platform and its add-ons.

## Operating model

Ownership boundaries are deliberate: an existing Azure Landing Zone owns
management-group and tenant-scoped policy; Terraform in this repository owns the
subscription baseline and shared platform infrastructure; Flux owns in-cluster
Kubernetes state; Azure Service Operator owns workload-team Azure dependencies;
and Backstage initiates golden-path workflows without being the source of truth.

The platform targets three profiles - `demo`, `nonprod`, and `prod` - with
cost-conscious defaults for `demo` and production-grade high availability and
security for `prod`.
