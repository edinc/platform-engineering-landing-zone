# ADR-0051: Cross-repo GitHub writes

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 05 - environment and subscription vending

## Context

Namespace vending writes manifests to `platform-cluster-state`, a separate
repository watched by Flux. GitHub Actions OIDC solves Azure authentication but
does not authorize writes to another GitHub repository. Personal access tokens
would weaken auditability and rotation.

## Decision

**Cross-repository writes use a dedicated GitHub App named
`platform-vending-bot`, not PATs or the Terraform GitHub provider.**

1. Operators store the App private key only in the Stage 01 seed Key Vault with
   `az keyvault secret set`; Terraform records only non-secret metadata so the
   PEM never enters Terraform state.
2. Workflows fetch the private key via Azure OIDC and mint a short-lived
   installation token in-process without exposing the PEM as a workflow output.
3. The namespace workflow uses `gh` and Git to push a branch and open a PR in
   `platform-cluster-state`.
4. Terraform may manage App installation repository scope, but it does not write
   Flux tenant manifests to the cluster-state repository.

## Consequences

- Cross-repo writes are PAT-free, auditable as a bot identity, and short-lived.
- The App registration itself is created manually or through GitHub's App API
  because the Terraform GitHub provider cannot create GitHub Apps.
- The seed Key Vault becomes a dependency for namespace vending workflows.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Personal access token stored in GitHub secrets | Long-lived credential with weaker identity and rotation controls. |
| Terraform `github_repository_file` writes | Terraform would own cluster state content, violating the GitOps repo ownership boundary. |
| Reuse `GITHUB_TOKEN` | Scoped to the current repository; cannot write to `platform-cluster-state`. |

## References

- [`infrastructure/terraform/github-app/`](../../infrastructure/terraform/github-app/)
- [GitHub App token action](https://github.com/actions/create-github-app-token)
- [`plan/stages/stage-05-vending.md`](../../plan/stages/stage-05-vending.md)
