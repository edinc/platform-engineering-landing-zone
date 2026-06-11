# ADR-0035: Use Renovate as the primary dependency updater

- Status: accepted
- Date: 2026-06-11
- Stage: Stage 06 - CI/CD and software supply chain

## Context

The platform spans GitHub Actions, Terraform providers/modules, container base
images, Helm charts, Kubernetes manifests, Node packages, and later Backstage
plugins. Dependabot provides useful security alerts but has weaker breadth for
Terraform, Helm, and container workflows.

## Decision

Use **Renovate as the primary dependency update engine** and keep Dependabot for
GitHub security alerts.

1. `renovate.json` is the source of truth for scheduled dependency update PRs.
2. Major updates require dependency-dashboard approval.
3. Platform automerge is disabled; maintainers review and merge after Stage 00/06
   quality gates pass.
4. Dependabot security alerts remain enabled in repository settings. Dependabot
   version-update PRs are not configured unless a later ADR changes this split.

## Consequences

- The platform gets one consistent PR flow across Terraform, Helm, Actions, and
  container dependencies.
- Security-only alerts still surface through GitHub native vulnerability
  reporting.
- Renovate must be installed as a GitHub App and granted repository access by an
  owner.
- Auto-merge can be revisited after Stage 11 golden-path consumers prove the
  update cadence and rollback path.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Dependabot for all updates | Weaker coverage for Helm, Terraform module nuance, and container governance. |
| Manual dependency sweeps | Too slow and easy to miss supply-chain drift. |
| Renovate with platform automerge enabled | Premature for infrastructure and workflow changes that can affect production paths. |

## References

- [`renovate.json`](../../renovate.json)
- [`docs/runbooks/renovate.md`](../runbooks/renovate.md)
- [`plan/stages/stage-06-cicd-supply-chain.md`](../../plan/stages/stage-06-cicd-supply-chain.md)
