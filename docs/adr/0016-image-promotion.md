# ADR-0016: PR-based image promotion with digest pinning

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 06 - CI/CD and software supply chain

## Context

The platform uses Flux as the only deployment mechanism. CI can build and sign
images, but it must not deploy directly to AKS or mutate cluster state without a
reviewable audit trail. Promotion also has different friction requirements:
`dev` should move quickly, while `nonprod` and `prod` require explicit review
and environment protection.

## Decision

Use **PR-based promotion with digest-pinned image references**.

1. `dev` may use Flux image automation to follow newly signed semver tags.
2. `nonprod` and `prod` promotions run `.github/workflows/promote-image.yml`.
   The workflow resolves the source image digest, verifies the cosign signature,
   creates a promoted tag, and opens a pull request in `platform-cluster-state`.
3. Cluster-state changes pin the image by digest through Kustomize image edits.
   A tag may be created for human readability, but the deployable reference is
   digest-pinned.
4. Cross-repository writes use the Stage 05 `platform-vending-bot` GitHub App.
5. Workflow jobs never call the Kubernetes API. Flux reconciles the reviewed
   cluster-state merge.

## Consequences

- Promotion history is visible as pull requests, labels, reviewers, and commits
  in the cluster-state repository.
- Prod promotion can use GitHub Environment reviewers and change-window controls
  without changing the build workflow.
- Digest pinning prevents mutable-tag drift between approval and reconciliation.
- Operators must keep the GitHub App key in the seed Key Vault rotated and the
  App installed on `platform-cluster-state`.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| CI deploys directly with `kubectl` or Helm | Violates the Flux-only deployment boundary. |
| Mutable tags in overlays | Allows tag drift after review and weakens rollback evidence. |
| Manual image edits only | Too slow and error-prone for the paved-road workflow. |

## References

- [ADR-0007: Cosign keyless signing](0007-image-signing.md)
- [ADR-0051: Cross-repo GitHub writes](0051-cross-repo-github-writes.md)
- [`docs/runbooks/release.md`](../runbooks/release.md)
- [`plan/stages/stage-06-cicd-supply-chain.md`](../../plan/stages/stage-06-cicd-supply-chain.md)
