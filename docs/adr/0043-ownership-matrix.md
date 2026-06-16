# ADR-0043: Ownership matrix is the canonical responsibility document

- Status: accepted
- Date: 2026-06-16
- Stage: Stage 10 - Multi-tenancy, onboarding, and ownership

## Context

The platform spans external ALZ-owned controls, repository-owned Terraform,
Flux-owned cluster state, Backstage catalog metadata, ASO-managed workload
resources, and team-owned application artifacts. Without one responsibility
source of truth, ownership drift can break access reviews, incident routing,
cost showback, and decommissioning.

## Decision

Use [`docs/runbooks/ownership-matrix.md`](../runbooks/ownership-matrix.md) as
the canonical RACI for controlled artifacts. Any change to artifact ownership or
accountability must update the matrix in the same PR as the implementation or
catalog change.

Backstage `Component` entities must set `spec.owner`, and CI validates the
owner-required contract through `policies/backstage/ownership-required.ts` and
the Stage 10 validator.

## Consequences

- Onboarding and decommissioning have a single source for responsible and
  accountable roles.
- Security and FinOps reviews can trace ownership from Entra groups to
  Backstage entities, namespaces, Azure tags, and cost records.
- Ownership changes require explicit review instead of implicit drift.

## Alternatives considered

| Alternative | Reason not chosen |
| --- | --- |
| Backstage catalog only | Does not cover external ALZ, Terraform state, GitOps, or cost artifacts. |
| CODEOWNERS only | Repository-centric and insufficient for Azure, Entra, and runtime ownership. |
| Per-runbook ownership notes | Easy to drift and hard to audit across stages. |

## References

- [Ownership matrix](../runbooks/ownership-matrix.md)
- [Stage 10 roadmap](../../plan/stages/stage-10-multitenancy-onboarding.md)
