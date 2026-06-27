# ADR-0019: Layer CI scanning with Trivy, Defender for Containers, CodeQL, and cosign verify

- Status: accepted
- Date: 2026-06-11
- Capability: supply chain & CI/CD

## Context

No single scanner covers all platform risk. The platform needs fast PR feedback,
registry-side vulnerability visibility, source-code scanning when GHAS is
licensed, and signature verification before promotion.

## Decision

Use **layered scanning**:

1. `trivy` runs in CI for container OS and library vulnerabilities, with high and
   critical findings blocking the reusable container workflow by default.
2. `checkov`, `tflint`, `conftest`, Azure Policy structure checks, and
   `kyverno test` remain the IaC and policy validation path through
   `.github/workflows/policy-checks.yml`.
3. Defender for Containers scans ACR pushes asynchronously and remains the Azure
   security posture signal for registry inventory.
4. CodeQL is available through the reusable policy workflow but remains opt-in
   until the repository or organization has GitHub Advanced Security enabled.
5. `promote-image.yml` re-verifies cosign signatures before opening
   cluster-state PRs.
6. Untrusted pull-request Terraform checks run without Azure OIDC or remote
   backend access. Azure-backed Terraform plans run only from protected,
   environment-gated workflows on private runners that can reach remote state.

## Consequences

- Developers get fast feedback before review, while Defender continues to cover
  registry inventory after push.
- GHAS cost is explicit and controlled per repository or organization.
- Scanner findings can disagree; the release runbook defines the exception path
  instead of weakening workflow defaults.
- GitOps platform admission control can trust supply chain & CI/CD signatures and SBOM attachment
  semantics.
- `harden-runner` starts in audit mode while endpoint allowlists are tuned; move
  signing and promotion workflows to block mode after smoke tests prove the
  required GitHub, Azure, ACR, and Sigstore endpoints.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Defender only | Asynchronous and too late for PR feedback. |
| Trivy only | Does not provide code scanning or Azure Security Center posture views. |
| Snyk or Aqua as mandatory tools | Adds paid third-party dependencies before native and open-source coverage is exhausted. |

## References

- [`docs/runbooks/ghas-cost.md`](../runbooks/ghas-cost.md)
- [`docs/runbooks/release.md`](../runbooks/release.md)
- [Supply chain & CI/CD](../how-it-works/supply-chain-cicd.md)
