# ADR-0033: AKS namespace as workload-scope vending unit

- Status: accepted
- Date: 2026-06-11
- Capability: tenancy vending

## Context

Not every team or workload needs a dedicated Azure subscription. The shared
platform AKS cluster from platform shared services can host smaller workloads when isolation,
quota, identity, and cost labels are enforced consistently. GitOps platform will later
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
- Flux reconciliation and policy enforcement are cross-capability gates completed in
  GitOps platform.
- The vended tenant Kustomization references the cluster-state Flux source by
  name. Because the platform stack registers that source as
  `azurerm_kubernetes_flux_configuration` named `platform-<profile>` (and
  `profile == environment` is a pre-existing invariant — the workflow writes to
  `clusters/overlays/<environment>` while the platform reconciles
  `clusters/overlays/<profile>`), the vending Terraform resolves
  `sourceRef.name` to `platform-<environment>` by default, overridable via the
  `flux_source_name` variable (protected `PLATFORM_FLUX_SOURCE_NAME` vending
  environment variable). An alternative is the
  `clusterconfig.azure.com/use-managed-source: "true"` annotation used by the
  platform's own Kustomizations, which lets the Flux extension rewrite the
  `sourceRef` and removes the name dependency; it is recorded as a future
  hardening option in [the vending runbook](../runbooks/vending.md).

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Always vend a subscription per workload | Higher cost and operational overhead for small workloads. |
| Let teams self-create namespaces | Bypasses identity, quota, labels, and network baseline controls. |
| Manage Kubernetes objects directly from Terraform | Conflicts with the GitOps ownership boundary; Flux owns in-cluster state. |

## References

- [Tenancy vending](../how-it-works/tenancy-vending-onboarding.md)
- [`infrastructure/terraform/vending/aks-namespace/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/vending/aks-namespace/)
- [ADR-0036: Kyverno as single in-cluster policy engine (seeded)](README.md)
