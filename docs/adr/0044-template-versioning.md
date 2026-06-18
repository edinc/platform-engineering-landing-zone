# ADR-0044: Golden path template versioning

- Status: accepted
- Date: 2026-06-16
- Stage: Stage 11 - Golden paths v1

## Context

Stage 11 introduces Backstage templates that create downstream repositories and
reviewed vending PRs. Template changes can break generated repository contracts,
CI wiring, GitOps layout, or ownership metadata if consumers cannot tell which
contract version they received.

## Decision

Every Stage 11 template declares a platform template contract version using:

- `metadata.annotations.scaffolder.platform.example.io/api-version:
  scaffolder.platform.example.io/v1`
- `metadata.deprecated: false`

Major contract changes require a new template path or name, documentation of the
migration path, and a deprecation notice on the old template before removal.
Generated repositories also carry Renovate config so dependency and workflow
updates can be proposed without changing the original generation contract.

## Consequences

- Template consumers can trace generated content to a stable contract.
- Platform maintainers can evolve templates without silently breaking existing
  services.
- Deprecation becomes explicit catalog metadata instead of a wiki-only process.

## Alternatives considered

| Alternative | Reason not chosen |
| --- | --- |
| Git tag only | Tags help source control but are not visible to Backstage users at template selection time. |
| No versioning until v2 | MVP templates already create production-facing repos and need a migration contract. |

## References

- [`templates/`](../../templates/)
- [`plan/stages/stage-11-golden-paths.md`](../../plan/stages/stage-11-golden-paths.md)
