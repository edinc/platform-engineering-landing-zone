# ADR-0036: Kyverno is the single in-cluster policy engine

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 07 - GitOps and in-cluster platform

## Context

The AKS baseline must enforce Kubernetes admission policy for labels, resource
limits, Pod Security, network posture, and signed images. Running Azure Policy
for AKS/Gatekeeper beside Kyverno would create duplicate admission paths,
conflicting constraints, and extra resource pressure.

## Decision

Use Kyverno as the only in-cluster admission engine. The AKS Terraform stack
keeps `azure_policy_enabled = false`, and Stage 07 installs Kyverno and the
`policies/kyverno/` bundle through Flux.

Azure Policy continues to govern Azure control-plane requirements. OPA/Rego via
`conftest` continues to validate Terraform plan-time assertions. Kyverno governs
Kubernetes admission and mutation.

## Consequences

- Policy ownership stays explicit by engine and lifecycle.
- CI must run `make policy-test-kyverno` for Kubernetes admission changes.
- The optional/reference AKS baseline policy pack must not enable the AKS Policy
  add-on unless a future ADR replaces this decision.
- Kyverno performance, webhook timeouts, and policy exceptions become Stage 07
  operational responsibilities.
- Kyverno verifies signed images from the private platform ACR by running its
  Azure registry credential helper with the AKS kubelet managed identity client
  ID. The kubelet identity already has `AcrPull`, which avoids introducing a
  separate static registry secret for admission-time verification.
- The Kyverno HelmRelease gets a longer recovery budget than the default Helm
  action timeout because post-upgrade migration hooks can exceed five minutes
  after demo-cluster cold starts. The parent Flux `platform-controllers`
  Kustomization must keep a longer wait timeout than the Kyverno HelmRelease.
- The chart's optional `policyReportsCleanup` hook is disabled because the
  upstream chart version references a removed `bitnami/kubectl` image. Admission
  policy enforcement, reports controller deployment, and image verification stay
  enabled.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Azure Policy for AKS/Gatekeeper | Duplicates Kyverno admission and conflicts with the roadmap's single-engine posture. |
| Gatekeeper only | Weaker fit for generate/mutate rules and signed-image verification in this roadmap. |
| No admission engine | Fails signed-image, label, resource, and Pod Security acceptance criteria. |

## References

- [`infrastructure/terraform/platform/aks.tf`](../../infrastructure/terraform/platform/aks.tf)
- [`policies/kyverno/`](../../policies/kyverno/)
- [`plan/stages/stage-07-gitops-incluster.md`](../../plan/stages/stage-07-gitops-incluster.md)
