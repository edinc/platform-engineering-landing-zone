# Cluster-state repository (Stage 04)

This composition creates the separate `platform-cluster-state` repository that
Flux watches for cluster desired state. It intentionally lives outside the
platform repository so workload and platform Kubernetes manifests have a smaller
blast radius than the Terraform/source repository.

## What this stack owns

| Capability | Resource |
|------------|----------|
| Repository | `github_repository` |
| Seed layout | `github_repository_file` for `clusters/_base`, overlays, `tenants`, README, and CODEOWNERS |
| Default branch | `github_branch_default` |
| Branch protection | `github_branch_protection` with PR review requirement; status checks are opt-in until Stage 06 workflows exist |

Seed files are created before branch protection is enforced and then treated as
bootstrap content. Later changes to the protected default branch must flow
through PRs rather than direct Terraform commits.

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
