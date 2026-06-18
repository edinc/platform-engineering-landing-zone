# AKS workload namespace request

Generated from the AKS workload namespace golden path.

This PR contains:

- a `NamespaceVendingRequest` for `${{ values.namespace }}`;
- a Backstage `Resource` entity owned by `group:default/pe-app-team-${{ values.teamName }}`;
- quota tier `${{ values.quotaTier }}` mapped to concrete CPU, memory, and pod
  limits.

After merge, `.github/workflows/vend-namespace.yml` validates the request,
applies the namespace Terraform stack, and opens the Flux
cluster-state PR for the generated namespace manifests.
