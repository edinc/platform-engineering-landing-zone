# ADR-0018: Developer inner loop uses devcontainers and Tilt

- Status: accepted
- Date: 2026-06-16
- Capability: multi-tenancy & onboarding

## Context

Golden-path templates need a consistent developer inner-loop before service
templates are introduced. Developers should be able to open a generated
repository, get the right tools, and iterate against the dev cluster without
depending on local machine drift or portal access.

## Decision

Use generated **devcontainers** plus **Tilt** as the primary inner-loop path.
Each golden-path template must include a `.devcontainer/` and a Tiltfile or
documented Tilt extension so developers can run multi-service reloads quickly.

Document **Bridge to Kubernetes** as a secondary VS Code option for
single-service workflows. Do not make it the only path because upstream
investment and feature coverage are less predictable. Reject Telepresence for
the MVP because it adds operational complexity and another network-control
surface before the platform needs it.

## Consequences

- Golden-path templates inherit a predictable local toolchain and do not assume
  developers have platform CLIs installed globally.
- Tilt becomes the supportable path for multi-service development against dev.
- Bridge to Kubernetes remains available for teams that accept its constraints.
- `pectl` stays roadmap-only for future-option planning.

## Alternatives considered

| Alternative | Reason not chosen |
| --- | --- |
| Bridge to Kubernetes as primary | Single-service focused and reduced upstream investment risk. |
| Telepresence | Higher operational complexity and additional traffic interception controls. |
| Local-only Docker Compose | Does not validate Workload Identity, namespace policy, or cluster integration. |

## References

- [Tenancy vending and onboarding](../how-it-works/tenancy-vending-onboarding.md)
- [Team onboarding runbook](../runbooks/team-onboarding.md)
