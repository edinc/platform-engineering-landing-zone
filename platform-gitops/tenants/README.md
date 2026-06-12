# Vended tenants

Stage 05 namespace vending writes tenant manifests under:

```text
tenants/<team>/<environment>/<namespace>/bootstrap/
tenants/<team>/<environment>/<namespace>/workloads/
tenants/<team>/<environment>/<namespace>-flux-kustomization.yaml
```

The environment overlay indexes the `bootstrap/` directory first so the
namespace, quota, network policy, Flux ServiceAccount, and namespace-scoped
RoleBinding exist before the tenant-scoped Kustomization reconciles `workloads/`
through impersonation.
