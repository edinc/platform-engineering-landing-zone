# Stage 06 — CI/CD & software supply chain

## Goal

Provide a paved-road CI/CD layer with no long-lived secrets, signed
artifacts, generated SBOMs, scanned images, and explicit image-promotion
semantics — *before* the platform builds Backstage or golden paths.

## Scope (in)

### Reusable GitHub Actions workflows

In `.github/workflows/` and `workflows/` (as reusable):

- `terraform-plan-apply.yml` — OIDC-federated `terraform plan` on PR,
  `apply` on merge with environment protection.
- `container-build-sign.yml` — Buildx multi-arch build, push to ACR,
  generate SBOM (`syft`), sign keyless (`cosign sign`), attach provenance.
- `helm-publish.yml` — package + sign Helm chart to ACR as OCI artifact.
- `promote-image.yml` — **PR-promotion** workflow: takes (image, source env,
  target env), verifies signature, re-tags to a digest-pinned promoted tag,
  opens a PR against `platform-cluster-state` (using the Stage-05
  `platform-vending-bot` GitHub App for cross-repo write).
- `policy-checks.yml` — `conftest` (Rego) + `kyverno test` + tflint + checkov.
- `techdocs-publish.yml` — builds and publishes Backstage TechDocs to the
  Azure Blob storage account (provisioned in Stage 09); consumed by all
  golden-path templates.
- `gitops-push.yml` — *only* used by the Backstage golden path; **commits**
  Flux manifests to `platform-cluster-state` and opens a PR. It does **not**
  call the cluster API. Deployment happens via Flux reconciliation, which
  is the platform's only deploy mechanism (ADR-0002).
- All reusable workflows pinned to **immutable SHAs** (not tags) and the
  caller workflows use `step-security/harden-runner` for SLSA L3
  hermeticity.

### Supply-chain controls

- **OIDC federated identity** from GitHub to every Azure subscription used.
- **`cosign` keyless signing** via GitHub OIDC; signature stored in ACR's
  OCI signature schema. Sigstore endpoints (`rekor.sigstore.dev`,
  `fulcio.sigstore.dev`, `tuf.sigstore.dev`) must be in the Stage 03
  Firewall allowlist (cross-reference).
- **SBOM** generated via `syft` (SPDX + CycloneDX) and attached to the image
  as an OCI artifact.
- **Provenance** attestation (SLSA L3 target). Hermeticity via
  `step-security/harden-runner` and SHA-pinned reusable workflows.
- **Scanning** layered:
  - **`trivy`** in CI for OS + library + IaC scanning.
  - **Defender for Containers** scans on push to ACR.
  - **CodeQL** for source-code scanning (GHAS — requires GitHub Advanced
    Security licence; cost recorded in `docs/runbooks/ghas-cost.md` and
    in §13 plan.md open questions).
  - **Renovate** (deployed as a GitHub App + `renovate.json` config in
    the repo) for dependency PRs (Renovate preferred for Helm/OCI/Terraform
    breadth). **Dependabot** retained for security-only alerts (auto-merge
    rule on patch CVEs).
- **Base-image governance**: approved bases mirrored in ACR; renovate auto-PRs
  base updates; ACR Tasks (VNet-injected agent pool — Stage 04) rebuild
  downstream images.
- **Kyverno verify** policies (deployed in Stage 07) verify cosign signatures
  before scheduling pods.

### Image-promotion semantics (ADR-0016)

- **dev**: Flux **image-automation** auto-bumps on new tag pushes (semver
  filter).
- **nonprod**: PR-promotion only. A `promote-image.yml` opens a PR against
  `platform-cluster-state/clusters/overlays/nonprod/...` pinning the digest.
- **prod**: same as nonprod with required reviewers + change window check.
- **Signature re-verification** on every promotion PR.

## Scope (out)

- Backstage app itself (Stage 09).
- Custom platform CLI / API (Stage 13).

## Deliverables

- All reusable workflows above.
- `renovate.json` at the repo root + `docs/runbooks/renovate.md`.
- `docs/runbooks/ghas-cost.md` — GHAS licence footprint + opt-in matrix.
- `docs/adr/0016-image-promotion.md`.
- `docs/adr/0019-ci-scanning.md`.
- `docs/runbooks/release.md` — operator guide for promotion.
- Smoke-test: a sample "hello" image built, signed, scanned, promoted across
  3 envs end to end.

## Dependencies

- Stage 00 (GitHub Environments), Stage 01 (OIDC), Stage 04 (ACR +
  `platform-cluster-state` repo), Stage 05 (`platform-vending-bot` GitHub
  App for cross-repo writes).

## Decisions / ADRs

- **ADR-0007** Cosign keyless (revisit Notation if ACR pushes alignment).
- **ADR-0016** PR-based promotion with digest pinning + sig re-verify.
- **ADR-0019** Trivy + Defender for Containers + CodeQL + cosign verify.
- **ADR-0022** Conventional Commits + Release Please for reusable
  workflows / Helm charts / Backstage plugins (moved here from Stage 00).
- **ADR-0035** Renovate as primary dep updater; Dependabot for security alerts
  only.
- **ADR-0002** GitOps deploy boundary — **no workflow calls the cluster
  API for deploys**. All deployments happen via Flux reconciliation
  triggered by commits to `platform-cluster-state`.

## Technologies

| Concern | Choice |
|---------|--------|
| CI | GitHub Actions |
| Federation | OIDC to Azure |
| Build | Buildx |
| Signing | cosign keyless |
| SBOM | syft (SPDX + CycloneDX) |
| Scanning (CI) | Trivy + CodeQL |
| Scanning (registry) | Defender for Containers |
| Dep updates | Renovate |
| Provenance | GitHub OIDC + cosign attestations (SLSA L3 target) |

## Acceptance criteria

1. A new feature branch produces a signed image, SBOM, and provenance, all
   discoverable via `cosign tree <ref>`.
2. Merge to `main` auto-bumps the dev overlay in `platform-cluster-state`; Flux
   reconciles in < 5 min.
3. `promote-image.yml` opens a PR against nonprod with a digest pin; signature
   re-verification step is green; merging deploys to nonprod.
4. Unsigned image deployment is **blocked at admission** by Kyverno (validated
   in Stage 07).
5. Renovate PR updates a base image; the change ripples through downstream
   images automatically.

## Risks

- **GHA OIDC scoping bugs** → enforce `environment:` claim in federation
  trust; deny-by-default for cross-repo reuse.
- **SBOM noise** → store as ACR OCI artifact, not in repo.
- **Promotion friction** → measure PR-open → merge latency; tune required
  reviewers; provide a "promote latest signed dev tag" shortcut workflow.
- **Cosign keyless expiry windows** → document Rekor + Fulcio implications;
  verify cluster nodes have correct time sync.
