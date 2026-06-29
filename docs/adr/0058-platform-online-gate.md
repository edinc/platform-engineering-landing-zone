# ADR-0058: PLATFORM_ONLINE gate for platform-dependent workflows

- Status: accepted
- Date: 2026-06-29
- Capability: CI/CD

## Context

Two workflows fail or queue noisily when the demo platform is torn down. The
nightly `ttl-sweep.yml` runs on a GitHub-hosted runner but authenticates to a
demo subscription that may be decommissioned, so OIDC login or `az resource
list` errors turn the schedule red. Backstage publish, chart, and smoke jobs
target the self-hosted `[self-hosted, azure, private-acr, swedencentral]`
runner; when that runner is offline those jobs queue indefinitely or skip on
every PR, spamming repository health signals.

We need one consolidated, fail-safe switch that lets platform-dependent jobs
no-op cleanly while platform-independent validation keeps running.

## Decision

**Introduce a repository variable `PLATFORM_ONLINE`; platform-dependent jobs run
only when it is `'true'`.**

- Backstage publish/sign/smoke moves out of `ci-backstage.yml` into a dedicated
  `cd-backstage.yml`. `ci-backstage.yml` keeps PR validation only (app, helm,
  contract) so PRs stay clean. `cd-backstage.yml` triggers on push-to-`main` and
  dispatch, behind a single `gate` job that resolves `PLATFORM_ONLINE`.
- Publish, chart, deployment-values, and smoke jobs additionally require
  `github.ref == 'refs/heads/main'`, preserving the trunk-only supply-chain
  invariant from the previous design.
- `ttl-sweep.yml` runs its scheduled sweep only when `PLATFORM_ONLINE == 'true'`;
  manual `workflow_dispatch` can still force a run for investigation.
- Default (unset) is fail-safe: jobs skip green rather than failing or queueing.

## Consequences

- Offline platform: validation stays green, platform jobs skip, health signals
  stop flapping. Online: set `PLATFORM_ONLINE=true` to restore publish/sweep.
- `PLATFORM_ONLINE` is a coarse, repo-wide lifecycle switch shared by Backstage
  CD and FinOps TTL. Owners must remember to flip it on after platform recovery.
- CD is a separate workflow, so it no longer hard-depends on CI jobs; publish
  runs on push-to-`main` only. To keep the pre-merge→publish coupling, the
  Backstage app, contract, and Helm-lint jobs are required status checks on
  `main`, so unvalidated code cannot merge and CD always publishes validated
  trunk code.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Auto-cancel queued self-hosted jobs via timeouts | Still records cancelled (non-green) checks. |
| Make publish jobs non-blocking only | Leaves skipped/red noise; no consolidation. |
| Per-capability/per-environment flags | More precise but heavier; deferred until profiles need divergent control. |

## References

- [`.github/workflows/cd-backstage.yml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/.github/workflows/cd-backstage.yml)
- [`.github/workflows/ci-backstage.yml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/.github/workflows/ci-backstage.yml)
- [`.github/workflows/ttl-sweep.yml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/.github/workflows/ttl-sweep.yml)
- [ADR-0048: Runner connectivity model](0048-runner-connectivity.md)
