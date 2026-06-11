# ADR-0033: AKS namespace as workload-scope vending unit

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 05 - environment and subscription vending

## Context

Not every team or workload needs a dedicated Azure subscription. The shared
platform AKS cluster from Stage 04 can host smaller workloads when isolation,
quota, identity, and cost labels are enforced consistently. Stage 07 will later
reconcile the manifests with Flux and Kyverno.

## Decision

**AKS namespace vending is the default workload-scope unit when subscription
blast-radius or billing isolation is not required.**

1. Namespace vending creates an Azure user-assigned managed identity, federated
   identity credential, ACR pull assignment, and Key Vault Secrets User
   assignment.
2. Terraform renders a Flux-compatible tenant manifest bundle containing the
   namespace, RBAC, ResourceQuota, default-deny NetworkPolicy, egress allowlist
   NetworkPolicy, ServiceAccount, and Kustomization files.
3. The workflow commits the rendered bundle to
   `platform-cluster-state/tenants/<team>/<env>/` using the dedicated vending
   GitHub App.

## Consequences

- Teams get a lower-friction onboarding path while preserving workload identity,
  quota, network-default-deny, and cost-label boundaries.
- Namespace vending does not replace subscription vending for workloads that
  require hard billing, quota, compliance, or blast-radius isolation.
- Flux reconciliation and policy enforcement are cross-stage gates completed in
  Stage 07.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Always vend a subscription per workload | Higher cost and operational overhead for small workloads. |
| Let teams self-create namespaces | Bypasses identity, quota, labels, and network baseline controls. |
| Manage Kubernetes objects directly from Terraform | Conflicts with the GitOps ownership boundary; Flux owns in-cluster state. |

## References

- [`plan/stages/stage-05-vending.md`](../../plan/stages/stage-05-vending.md)
- [`infrastructure/terraform/vending/aks-namespace/`](../../infrastructure/terraform/vending/aks-namespace/)
- [ADR-0036: Kyverno as single in-cluster policy engine (seeded)](README.md)
