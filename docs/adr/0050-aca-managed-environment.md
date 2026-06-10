# ADR-0050: ACA managed environment as a platform shared service

- Status: accepted
- Date: 2026-06-10
- Stage: Stage 04 - platform shared services

## Context

Stage 11 includes an Azure Container Apps golden path. That path needs a secure,
repeatable substrate before templates can safely deploy apps, networking, and
observability.

## Decision

**The Azure Container Apps managed environment is a Stage 04 platform shared
service; ACA apps remain workload/golden-path resources created later.**

1. The managed environment is VNet-injected and internal.
2. Logs are sent to Log Analytics when a workspace is supplied; otherwise Azure
   Monitor native destination is used until observability is wired.
3. `prod` includes a dedicated workload profile in addition to Consumption.
4. No Container Apps are deployed by this stack.

## Consequences

- Stage 11 can target a known environment rather than creating per-template
  substrates.
- Platform networking and Private Link posture is owned by Terraform before apps
  are introduced.
- ACA feature availability varies by region, so the region matrix must be kept
  current before production rollout.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Create ACA managed environments per app | Higher cost and fragmented ingress/observability controls. |
| Defer ACA environment to Stage 11 | Golden paths would need to create shared platform substrate, blurring ownership boundaries. |
| Use only AKS for MVP | Stage 11 explicitly includes an ACA service golden path. |

## References

- [`plan/stages/stage-04-platform-shared-services.md`](../../plan/stages/stage-04-platform-shared-services.md)
- [`infrastructure/terraform/platform/aca-environment.tf`](../../infrastructure/terraform/platform/aca-environment.tf)
