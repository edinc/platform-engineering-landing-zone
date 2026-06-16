# ADR-0020: Build the MVP developer portal with Backstage

- Status: accepted
- Date: 2026-06-15
- Stage: Stage 09 - Backstage MVP

## Context

The platform needs a developer portal for catalog, TechDocs, Kubernetes views,
GitOps status, GitHub workflow visibility, Cost Insights, and golden-path
workflows. The MVP must avoid custom plugin development where community plugins
are sufficient.

## Decision

Build the MVP portal with Backstage and keep it close to upstream. Use community
plugins for Kubernetes, GitHub Actions, Flux, TechDocs, Scaffolder, Permission
Framework, and Cost Insights. The MVP adds a small platform-owned Cost Insights
API adapter that reads the Stage 08 CSV showback output and feeds the community
Cost Insights UI; no custom UI plugin is introduced.

Re-evaluate Backstage against Port, Humanitec, Cortex, and similar SaaS options
in Stage 13 after at least 12 months of operational data or sustained Backstage
maintenance pain.

## Consequences

- The platform owns the Backstage runtime, dependency upgrades, and plugin
  compatibility.
- Developer experience is code-owned and can be adapted to the platform roadmap.
- Custom plugins remain out of scope for MVP to reduce maintenance burden.
- Build-vs-buy remains an explicit future decision instead of an implicit lock-in.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Port | Strong SaaS option, but introduces vendor dependency before MVP usage is proven. |
| Humanitec | Strong platform orchestration, but overlaps Stage 05/11 workflow ownership. |
| Cortex/OpsLevel | Strong catalog/scorecards, but less aligned with in-cluster GitOps workflows. |

## References

- [`plan/stages/stage-09-backstage-mvp.md`](../../plan/stages/stage-09-backstage-mvp.md)
- [`backstage/`](../../backstage/)
