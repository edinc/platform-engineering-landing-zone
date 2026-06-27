# ADR-0050: ACA managed environment as a platform shared service

- Status: accepted
- Date: 2026-06-10
- Capability: platform shared services

## Context

The golden paths capability includes an Azure Container Apps golden path. That path needs a secure,
repeatable substrate before templates can safely deploy apps, networking, and
observability.

## Decision

**The Azure Container Apps managed environment is a platform shared services capability; ACA apps remain workload/golden-path
resources created later.**

1. The managed environment is VNet-injected and internal.
2. Logs are sent to Log Analytics when a workspace is supplied; otherwise Azure
   Monitor native destination is used until observability is wired.
3. `prod` includes a dedicated workload profile in addition to Consumption.
4. No Container Apps are deployed by this stack.

## Consequences

- The golden paths capability can target a known environment rather than creating per-template
  substrates.
- Platform networking and Private Link posture is owned by Terraform before apps
  are introduced.
- ACA feature availability varies by region, so the region matrix must be kept
  current before production rollout.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Create ACA managed environments per app | Higher cost and fragmented ingress/observability controls. |
| Defer ACA environment to golden paths | Golden paths would need to create shared platform substrate, blurring ownership boundaries. |
| Use only AKS for MVP | The golden paths capability explicitly includes an ACA service golden path. |

## References

- [platform shared services](../how-it-works/platform-services.md)
- [`infrastructure/terraform/platform/aca-environment.tf`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/infrastructure/terraform/platform/aca-environment.tf)
