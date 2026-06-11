# ADR-0022: Use Conventional Commits for release automation inputs

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 06 - CI/CD and software supply chain

## Context

Reusable workflows, Helm charts, templates, and later Backstage plugins need a
consistent release signal. The repository is currently stage-driven, so full
Release Please automation is not enabled yet, but commit semantics should be
stable before generated golden-path repositories consume these workflows.

## Decision

Use **Conventional Commits** as the release input convention for reusable
workflow, Helm chart, template, and plugin changes.

1. Feature changes use `feat:`, fixes use `fix:`, and breaking changes include
   the `!` marker or `BREAKING CHANGE:` footer.
2. Stage implementation branches may contain ordinary local commits, but PR
   titles and release-bound commits must use Conventional Commit syntax.
3. Release Please is the preferred future release automation for reusable
   workflows, Helm charts, Backstage plugins, and templates once the repository
   starts cutting versioned releases.

## Consequences

- Generated consumers can reason about version impact without bespoke labels.
- Release automation can be introduced later without rewriting history or
  changing contribution guidance.
- Maintainers must correct PR titles before squash-merging release-bound changes.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Manual changelogs only | Easy to drift and hard for generated consumers to interpret. |
| GitHub labels as release inputs | Labels are useful, but commit messages travel with forks and generated repos. |
| Enable Release Please immediately | Premature until the repo has stable versioned surfaces to publish. |

## References

- [`docs/runbooks/release.md`](../runbooks/release.md)
- [`plan/stages/stage-06-cicd-supply-chain.md`](../../plan/stages/stage-06-cicd-supply-chain.md)
