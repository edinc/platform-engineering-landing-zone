# Platform cluster-state seed

This directory is the source template for the separate
`platform-cluster-state` repository created by the Stage 04
`infrastructure/terraform/cluster-state-repo` stack.

Stage 07 installs the Microsoft-managed Flux extension on AKS and points one
root Flux Kustomization at `clusters/overlays/<env>` in that separate
repository. Terraform copies this directory into `platform-cluster-state` and
mirrors the tested Kyverno policies from `policies/kyverno/` into
`clusters/_base/policies/kyverno/`.

Stage 08 extends the seed with observability and SRE primitives under
`clusters/_base/addon-config/observability`: OTel conventions, Sloth SLOs,
Prometheus alert rules with `runbook_url` annotations, dashboards-as-code, KEDA
scale-to-zero patterns, and rightsizing automation.

## Layout

| Path | Purpose |
|------|---------|
| `clusters/_base/` | Shared platform add-ons installed by Flux. |
| `clusters/_base/controllers/` | Namespaces, Helm repositories, and controller HelmReleases that establish CRDs. |
| `clusters/_base/addon-config/` | CRD-backed resources and Kyverno policies applied after controllers are ready. |
| `clusters/_base/addon-config/observability/` | Stage 08 observability, SLO, alerting, and FinOps manifests. |
| `clusters/overlays/demo` | Demo overlay with cost-conscious defaults. |
| `clusters/overlays/nonprod` | Non-production overlay with enforcement enabled. |
| `clusters/overlays/prod` | Production overlay with HA/security-oriented patches. |
| `tenants/` | Target for Stage 05 namespace vending and later golden paths. |

## Stage 07 dependency check

Before setting `enable_gitops = true` in the platform Terraform stack, confirm:

1. The `platform-cluster-state` repository exists and contains this seed layout.
2. The target overlay path exists for the platform profile.
3. Private repository access is configured through a supported Flux provider,
   and strict post-build substitution replaces the cluster-state source URL,
   branch, provider, DNS, Key Vault, and Workload Identity values.
4. The Stage 05 `vend-namespace.yml` workflow can open a PR into `tenants/`.
5. `make stage07-contracts stage08-contracts policy-test-kyverno kubeconform` passes in this repo.

The tree under `platform-gitops/` is a seed template. Terraform mirrors
`policies/kyverno/*.yaml` into
`clusters/_base/addon-config/policies/kyverno/` when creating
`platform-cluster-state`; keep the mirrored seed copies in this directory
aligned with the tested source files when changing policy content.
