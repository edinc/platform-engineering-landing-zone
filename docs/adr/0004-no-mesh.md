# ADR-0004: No service mesh at MVP

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 07 - GitOps and in-cluster platform

## Context

The MVP platform needs secure workload delivery, ingress TLS, policy
enforcement, observability, and default-deny networking without adding another
control plane that teams must operate during the first production rollout.
Azure CNI Overlay with Cilium, Kubernetes NetworkPolicy, ingress-nginx, and
OpenTelemetry cover the current Stage 07 requirements.

## Decision

Do not introduce a service mesh in the MVP. Stage 07 uses NetworkPolicy,
Workload Identity, cert-manager, ExternalDNS, Kyverno, ingress-nginx, and
OpenTelemetry collectors as the default in-cluster platform layer.

## Consequences

- The platform avoids mesh sidecar cost, upgrade risk, and policy overlap during
  the MVP.
- mTLS between workloads is not a default platform guarantee before a future ADR
  reopens the mesh decision.
- Egress controls stay split between Azure Firewall for non-demo profiles and
  Cilium/Kubernetes NetworkPolicy in cluster.
- Stage 13 can re-evaluate Istio, Cilium service mesh, or another mesh once the
  MVP golden paths and SLOs are proven.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Istio AKS add-on | Adds operational complexity before platform teams have the baseline running. |
| Cilium service mesh | Promising fit with the dataplane, but deferred until MVP reliability and ownership patterns are proven. |
| Linkerd | Simple mesh, but not Azure-native enough for the first platform baseline. |

## References

- [`plan/stages/stage-07-gitops-incluster.md`](../../plan/stages/stage-07-gitops-incluster.md)
- [ADR-0031: Default-deny egress and FQDN allowlist](0031-default-deny-egress.md)
