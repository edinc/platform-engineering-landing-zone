# ADR-0040: Upptime is the MVP status page

- Status: accepted
- Date: 2026-06-12
- Stage: Stage 08 - Observability, SRE, FinOps

## Context

The platform needs a visible service-status surface for incidents and planned
maintenance, but Stage 08 should not add another stateful application to operate
before Backstage exists.

## Decision

Use Upptime for the MVP status page. It is GitHub-Pages based, low-ops, and fits
the repository's GitHub-first workflow model. Status checks and incident updates
are stored as code and can link to the Stage 12 incident process.

Cachet remains documented as a secondary option because it provides a richer
self-hosted status page but is in upstream maintenance mode and would add
runtime ownership before the MVP needs it.

## Consequences

- The status page can launch without operating another database-backed service.
- GitHub Pages availability becomes part of the status-page dependency model.
- Stage 12 incident workflows must include a status-page update step.
- If GitHub-hosted status pages are unacceptable for a tenant, Stage 13 can
  re-evaluate Cachet or a managed status-page provider.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Cachet | More operational overhead and upstream maintenance concerns. |
| Custom Backstage status plugin | Backstage is Stage 09 and should not block the MVP status page. |
| Azure Static Web Apps custom page | More custom code than Upptime for the same MVP outcome. |

## References

- [`docs/runbooks/platform-slos.md`](../runbooks/platform-slos.md)
- [`plan/stages/stage-08-observability-sre-finops.md`](../../plan/stages/stage-08-observability-sre-finops.md)
