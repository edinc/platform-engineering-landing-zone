# ADR-0007: Use cosign keyless signing for container and chart artifacts

- Status: accepted
- Date: 2026-06-11
- Capability: supply chain & CI/CD

## Context

The platform must prove artifact integrity without introducing long-lived signing
keys. The supply chain & CI/CD capability builds containers and Helm charts before the GitOps platform enforces
admission policy, so signatures must be available in ACR as OCI artifacts and
verifiable later by Kyverno.

## Decision

Use **cosign keyless signing with GitHub OIDC** for platform-built images and
Helm chart OCI artifacts.

1. Workflows request short-lived GitHub OIDC tokens (`id-token: write`) and run
   `cosign sign --yes` against digest-pinned image or chart references.
2. Signatures, SBOMs, and attestations are stored beside the artifact in ACR's
   OCI-compatible storage. No private signing key is committed, stored in
   GitHub, or placed in Key Vault for normal builds.
3. Promotion workflows re-run `cosign verify` before opening any non-dev or prod
   cluster-state pull request.
4. GitOps platform Kyverno policies verify these cosign signatures before scheduling
   signed-image-required workloads.

## Consequences

- The signing identity is auditable as the GitHub workflow identity and branch
  or environment protections govern who can mint a signature.
- Sigstore services (`rekor`, `fulcio`, `tuf`, and `oauth2`) remain mandatory
  egress dependencies in the connectivity & egress allowlist.
- Verifiers must use certificate identity constraints rather than shared public
  keys.
- Offline verification is weaker than key-based signing unless Rekor and Fulcio
  bundles are retained; release runbooks must record verification evidence.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Long-lived cosign key in Key Vault | Adds key custody, rotation, and blast-radius risks that OIDC avoids. |
| Notation / Notary v2 only | Promising ACR alignment, but the roadmap defers this comparison to future-option planning. |
| Unsigned images with registry scanning only | Does not prove provenance and cannot support GitOps platform admission enforcement. |

## References

- [Supply chain & CI/CD](../how-it-works/supply-chain-cicd.md)
- [ADR-0016: PR-based image promotion](0016-image-promotion.md)
- [ADR-0031: Default-deny egress and FQDN allowlist](0031-default-deny-egress.md)
