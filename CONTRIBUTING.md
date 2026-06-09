# Contributing

This repository implements the Azure Platform Engineering Landing Zone described
in [`plan/plan.md`](plan/plan.md). Keep changes aligned with the active stage in
[`plan/stages/`](plan/stages/).

## Workflow

1. Create or switch to a task-specific feature branch before implementation.
   Do not implement directly on `main` unless explicitly instructed.
2. Read the relevant stage file and any ADRs that govern the changed area.
3. Keep changes focused on the current stage boundary.
4. Add or update tests for behavior, policy, workflow, or infrastructure changes.
5. Run the smallest reliable validation set before opening a PR.

## Local toolchain

Use the devcontainer or install the pinned toolchain:

```sh
mise install
make bootstrap
```

`make bootstrap` requires `mise`; the devcontainer installs it before running
the bootstrap target.

Stage 00 validation:

```sh
make lint validate policy-test-rego policy-test-kyverno
```

## Pull requests

Every PR should explain the stage being changed, the acceptance criteria it
addresses, and the validation that was run. Implementation changes require
independent correctness, security, and architecture review passes before final
handoff.

Repository administrators should apply the branch protection ruleset in
[`.github/rulesets/main-branch-protection.json`](.github/rulesets/main-branch-protection.json)
so required status checks block merges into `main`.

The current CODEOWNERS file uses `@edinc` as an enforceable fallback because the
repository is user-owned. Replace those entries with the documented organization
teams if the repository moves under a GitHub organization. Do not enable
required code-owner review until the repository has at least one independent
reviewer or valid organization teams, otherwise pull requests can become
unmergeable.

Do not commit secrets, kubeconfigs, tenant-specific credentials, private keys,
or generated Terraform state.
