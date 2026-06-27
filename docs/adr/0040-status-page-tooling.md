# ADR-0040: Upptime is the MVP status page

- Status: accepted
- Date: 2026-06-12
- Capability: observability, SRE & FinOps

## Context

The platform needs a visible service-status surface for incidents and planned
maintenance, but the observability, SRE & FinOps capability should not add another stateful application to operate
before Backstage exists.

## Decision

Use Upptime for the MVP status page. It is GitHub-Pages based, low-ops, and fits
the repository's GitHub-first workflow model. Status checks and incident updates
are stored as code and can link to the reliability operations incident process.

Cachet remains documented as a secondary option because it provides a richer
self-hosted status page but is in upstream maintenance mode and would add
runtime ownership before the MVP needs it.

## Consequences

- The status page can launch without operating another database-backed service.
- GitHub Pages availability becomes part of the status-page dependency model.
- Reliability operations incident workflows must include a status-page update step.
- If GitHub-hosted status pages are unacceptable for a tenant, the roadmap & future options capability can
  re-evaluate Cachet or a managed status-page provider.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Cachet | More operational overhead and upstream maintenance concerns. |
| Custom Backstage status plugin | Backstage is part of the developer portal capability and should not block the MVP status page. |
| Azure Static Web Apps custom page | More custom code than Upptime for the same MVP outcome. |

## References

- [`docs/runbooks/platform-slos.md`](../runbooks/platform-slos.md)
- [observability, SRE & FinOps](../how-it-works/observability-sre-finops.md)
