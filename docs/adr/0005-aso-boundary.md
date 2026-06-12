# ADR-0005: Use ASO v2 with a curated ownership boundary

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 07 - GitOps and in-cluster platform

## Context

Workload teams need self-service Azure dependencies such as Service Bus topics,
PostgreSQL databases, Storage containers, and Key Vault secret projections. The
platform also needs a clear boundary between Terraform-owned shared
infrastructure and workload-owned Azure resources reconciled from Kubernetes.

## Decision

Install Azure Service Operator v2 cluster-wide through Flux with a curated
`crdPattern` allowlist:

```text
servicebus.azure.com/*;keyvault.azure.com/*;dbforpostgresql.azure.com/*;storage.azure.com/*
```

ASO-created resources must carry `managedBy: aso`. Stage 07 installs ASO and
its curated CRDs, but tenant Flux RBAC does not grant ASO write access until a
later stage adds admission policies that constrain Azure parent ownership. The
vended team RoleBinding is read-only and direct Entra access is namespace-scoped
AKS RBAC Viewer. Tenant users therefore cannot write ASO CRDs directly. Tenant
GitOps cannot write Key Vault secrets through ASO; secret consumption stays
read-only through Key Vault CSI or ESO. Terraform remains the owner for
subscription baseline, networking, AKS, ACR, Key Vault, Postgres server, Service
Bus namespace, and other platform shared services.

## Consequences

- Workload teams can declare approved Azure child resources through GitOps while
  Terraform continues to own shared substrate.
- The CRD allowlist limits blast radius during ASO upgrades.
- Resource tagging provides an audit boundary between ASO, Terraform, Flux, and
  manual exceptions.
- New Azure resource families require a PR that updates the allowlist, policies,
  runbooks, and golden paths.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Terraform creates every workload dependency | Too slow for app-team self-service and forces platform-owned state churn. |
| Full ASO CRD surface | Too broad for least privilege and upgrade safety. |
| Crossplane | Powerful, but adds a second cloud-control abstraction beyond the Azure-native default. |

## References

- [`platform-gitops/clusters/_base/platform/aso.yaml`](../../platform-gitops/clusters/_base/platform/aso.yaml)
- [`plan/stages/stage-07-gitops-incluster.md`](../../plan/stages/stage-07-gitops-incluster.md)
- [ADR-0032: Platform-internal eventing uses Azure Service Bus](0032-platform-eventing.md)
