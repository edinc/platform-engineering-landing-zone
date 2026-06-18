# Runbook: Release and image promotion

This runbook operates the paved-road build, signing, SBOM, and promotion flow.

Related decisions: [ADR-0007](../adr/0007-image-signing.md),
[ADR-0016](../adr/0016-image-promotion.md), and
[ADR-0019](../adr/0019-ci-scanning.md).

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Azure OIDC variables | Azure login without long-lived secrets. |
| Sigstore egress | Keyless signing and verification. |
| Platform ACR | Stores images, signatures, SBOMs, and Helm OCI artifacts. |
| `platform-vending-bot` | Opens cross-repo PRs in `platform-cluster-state`. |
| Protected GitHub Environments | Gate `nonprod` and `prod` promotion. |
| VNet-integrated self-hosted runner | Required for private ACR push/sign/promote operations and private Key Vault reads. |

Private runner images must include the GitHub Actions runner prerequisites plus
standard Unix tools (`bash`, `curl`, `git`, `jq`, and `rsync`). The reusable
workflows install the pinned mise toolchain for Azure CLI, GitHub CLI, Node.js,
cosign, and related platform tools, then fail fast if required base tools are
missing.

Set these protected environment variables for promotion verification when the
builder is not the caller repository:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TRUSTED_BUILDER_REPOSITORY` | Caller repository | Repository whose workflow identity is trusted to sign promotable images. |
| `TRUSTED_BUILDER_WORKFLOW` | `container-build-sign.yml` | Exact workflow file expected in the cosign certificate identity. |
| `TRUSTED_BUILDER_REF` | `refs/heads/main` | Protected main ref or immutable 40-character workflow commit SHA allowed to produce promotable signatures. |

`CLUSTER_STATE_REPO_OWNER` and `CLUSTER_STATE_REPO_NAME` are required protected
variables for promotion. Caller inputs may repeat those values for clarity, but
the workflow rejects any target repository that does not match the protected
variables.

## 1. Build a signed image

Caller repositories invoke `.github/workflows/container-build-sign.yml` with an
ACR image name and Docker context. If the caller does not provide a tag, the
workflow emits a semver-compatible dev tag of the form
`0.0.0-<run>.g<sha12>` so Flux image policies can select it. The workflow:

1. Authenticates to Azure with GitHub OIDC.
2. Builds and pushes a multi-arch image.
3. Resolves the pushed digest.
4. Scans the digest with Trivy.
5. Generates SPDX and CycloneDX SBOMs.
6. Signs and attaches SBOM/provenance evidence with cosign.

Verify evidence:

```bash
cosign verify \
  --certificate-identity "https://github.com/<owner>/<repo>/.github/workflows/container-build-sign.yml@<trusted-ref-or-sha>" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  <acr>.azurecr.io/<repo>/<image>@sha256:<digest>

cosign tree <acr>.azurecr.io/<repo>/<image>@sha256:<digest>
```

## 2. Publish a Helm chart

Caller repositories invoke `.github/workflows/helm-publish.yml` with
`chart_path`. The workflow packages the chart, pushes it to ACR as an OCI
artifact, and signs the digest with cosign.

## 3. Promote to nonprod or prod

Use `.github/workflows/promote-image.yml` with:

| Input | Example |
| --- | --- |
| `image_ref` | `<acr>.azurecr.io/apps/api:main-abc123` |
| `image_name` | `apps/api` |
| `source_environment` | `dev` |
| `target_environment` | `nonprod` |
| `kustomization_path` | `clusters/overlays/nonprod/apps/api` |

The workflow verifies the source signature, creates a promoted tag, updates the
target Kustomize image to a digest-pinned reference, and opens a PR in
`platform-cluster-state`. Merge the PR only after the target environment's
required reviewers approve.

## 4. Run the supply-chain smoke test

Use **Actions -> Supply-chain smoke test** to build the minimal
[`samples/hello-container`](../../samples/hello-container/) image through the
same reusable workflow used by golden paths. To exercise promotion, provide the
nonprod and prod `kustomization_path` values for a disposable smoke overlay and
enable the matching promotion inputs. Prod smoke promotion intentionally depends
on nonprod smoke promotion so the path proves dev -> nonprod -> prod ordering.
The smoke workflow and privileged reusable workflows intentionally use the fixed
`[self-hosted, azure, private-acr, swedencentral]` private-runner label set;
dispatchers cannot route privileged ACR/Key Vault work to arbitrary runners.

Run promotion smoke tests from `main`, or set the protected
`TRUSTED_BUILDER_REF` environment variable to the immutable workflow commit SHA
used for the smoke run. Promotion verification fails closed when the cosign
certificate identity does not match the trusted builder repository, workflow,
and ref.

## 5. Exceptions

Do not bypass signature verification for production. If Trivy or CodeQL findings
need a temporary exception:

1. Link the vulnerability, risk owner, and expiry date in the promotion PR.
2. Keep the exception scoped to the exact image digest or repository.
3. Create a follow-up issue to remove the exception.

## Rollback

1. Find the last known-good signed digest in the cluster-state history.
2. Open a PR that reverts the Kustomize image reference to that digest.
3. Confirm `cosign verify` still succeeds for the rollback digest.
4. Merge and let Flux reconcile. Do not use `kubectl rollout undo` as the
   persistent rollback mechanism.
