# Cluster-state repository (Stage 04)

This composition creates the separate `platform-cluster-state` repository that
Flux watches for cluster desired state. It intentionally lives outside the
platform repository so workload and platform Kubernetes manifests have a smaller
blast radius than the Terraform/source repository.

## What this stack owns

| Capability | Resource |
|------------|----------|
| Repository | `github_repository` |
| Seed layout | `github_repository_file` for `platform-gitops/` seed content, `policies/kyverno/` mirrored under `clusters/_base/addon-config/policies/kyverno/`, and CODEOWNERS |
| Default branch | `github_branch_default` |
| Branch protection | `github_branch_protection` with PR review requirement; status checks are opt-in until Stage 06 workflows exist |

Seed files are bootstrap-only. By default Terraform preserves the original
placeholder seed keys so existing state is not destroyed. Set
`stage07_seed_files_enabled = true` only on first repository creation before
branch protection exists. Later changes to the protected default branch must
flow through PRs rather than direct Terraform commits. Stage 07 promotes
`platform-gitops/` from a placeholder into the cluster-state seed and mirrors
the tested Kyverno bundle into
`clusters/_base/addon-config/policies/kyverno/` so the ordered
`platform-config` Flux Kustomization can apply the admission bundle.

`enable_branch_protection` defaults to `true`. Set it to `false` only for
constrained integration repositories where GitHub rejects branch protection on a
private repo. This bypass is guarded to the `demo` repository profile and
requires `branch_protection_bypass_reason`; enforce reviews/branch controls
manually or move the repo to a plan/organization that supports private-repo
protection.

## Prerequisites

- GitHub token with repository administration permissions for `github_owner`.
- Stage 01 state backend container `platform` already exists.

## Validation

```bash
terraform init -backend=false
terraform validate
```

## Stage handoff

Stage 05 vending and later Backstage/golden-path stages write manifests into this
repository. The Stage 05 GitHub App (`platform-vending-bot`) becomes the
canonical writer once introduced.
