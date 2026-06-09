# ADR-0021: Use pre-commit for local quality gates

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 00 - Foundation and repo bootstrap

## Context

Contributors need fast local feedback before CI runs. Stage 00 requires a
pre-commit framework and a clear split between lightweight local checks and
heavier CI validation.

## Decision

Use the `pre-commit` framework for local checks that are quick, deterministic,
and safe to run on every change:

- whitespace and final newline checks
- YAML and JSON syntax checks
- merge-conflict detection
- Terraform formatting through `pre-commit-terraform`

CI remains responsible for the full quality gate: Terraform validation, TFLint,
Checkov, OPA/Rego tests, Kyverno tests, kubeconform, Helm lint, and Backstage
stub validation.

## Consequences

- `make bootstrap` installs the local hooks.
- `make lint` runs all configured pre-commit hooks across tracked files.
- Heavier checks are not hidden inside pre-commit hooks where they would slow
  down every local commit.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Only GitHub Actions | Slower feedback and more avoidable CI failures. |
| Custom shell hooks | Harder to pin, share, and update consistently. |
| Run every CI tool in pre-commit | Too slow for normal development loops. |

## References

- [`plan/stages/stage-00-foundation.md`](../../plan/stages/stage-00-foundation.md)
- [pre-commit](https://pre-commit.com/)
