# ADR-0047: Split Azure, OPA/Rego, and Kyverno policy testing

- Status: accepted
- Date: 2026-06-09
- Capability: repository foundation

## Context

The platform uses policy at multiple layers. Azure Policy governs Azure
control-plane resources, OPA/Rego validates Terraform plan-time assertions, and
Kyverno validates or mutates Kubernetes resources in-cluster. These engines have
different input formats and semantics.

## Decision

Keep policy concerns separate:

| Policy area | Location | Engine | repository foundation test command |
|-------------|----------|--------|-----------------------|
| Azure control plane | `policies/azure/` | Azure Policy | Structure placeholder only in repository foundation. |
| Terraform plan-time assertions | `policies/rego/` | `conftest` / OPA Rego | `make policy-test-rego` |
| Kubernetes admission | `policies/kyverno/` | Kyverno CLI and in-cluster Kyverno | `make policy-test-kyverno` |

The initial Rego fixture enforces the mandatory Azure tag taxonomy from
the roadmap tag taxonomy. The initial Kyverno fixture uses standard
`app.kubernetes.io/*` labels for Kubernetes ownership and inventory metadata.

## Consequences

- `conftest` must not be used to claim Kyverno semantic validation.
- `kyverno test` must be used for Kyverno policy changes.
- Azure Policy definitions and assignments remain separate from Terraform
  plan-time Rego checks.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Single policy engine | No single engine validates Azure control plane, Terraform plans, and Kubernetes admission semantics correctly. |
| Azure Policy Gatekeeper add-on for AKS | The roadmap standardizes on Kyverno as the in-cluster admission engine. |
| Documentation-only policy guidance | Does not give CI a concrete regression signal. |

## References

- [roadmap](../roadmap/README.md)
- [repository foundation](../how-it-works/foundation.md)
