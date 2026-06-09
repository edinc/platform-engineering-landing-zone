# ADR-0023: Use GitHub with trunk-based short-lived branches

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 00 - Foundation and repo bootstrap

## Context

The platform repository needs a source-control model that supports rapid
iteration while protecting shared infrastructure, policy, and workflow changes.
Stage 00 also establishes GitHub Environments used later by OIDC federation,
deployment approvals, and image-promotion protection.

## Decision

Use GitHub as the SCM and `main` as the protected trunk branch. Contributors and
automation must create or switch to a task-specific feature branch before
starting implementation work unless the user explicitly requests direct work on
`main`.

Pull requests into `main` require:

- Stage-aligned scope and validation evidence.
- CODEOWNERS review from the relevant ownership route when a valid reviewer is
  available.
- Passing Stage 00 quality-gate workflows.
- Independent correctness, security, and architecture review passes before
  final handoff.

The importable repository ruleset is stored at
`.github/rulesets/main-branch-protection.json` and requires the Stage 00 quality
gate and Backstage CI stub status checks before merge. It intentionally does
not enforce code-owner approval while this repository is user-owned, because the
current fallback owner could otherwise make pull requests unmergeable. Enable
required code-owner approval after adding at least one independent reviewer or
moving the repository under an organization with the documented teams.

This repository is currently owned by the `edinc` user account, so CODEOWNERS
uses `@edinc` as the enforceable owner while comments document the intended
organization team routes. If the repository moves under an organization, replace
the fallback owner with the documented teams before enforcing code-owner review.

Define these GitHub Environments for downstream stages:

| Environment | Purpose | Protection guidance |
|-------------|---------|---------------------|
| `bootstrap` | Stage 01 remote state, OIDC federation, seed Key Vault, and secret-zero setup. | Platform infrastructure and security reviewers. |
| `dev` | First integration target for platform and golden-path changes. | Platform maintainers; short approval path. |
| `nonprod` | Pre-production validation for platform workflows and workload onboarding. | Platform infrastructure and security reviewers. |
| `prod` | Production platform operations. | Required platform, security, and operations reviewers. |

The environments are referenced by the Stage 00 Backstage CI stub so repository
administrators can create and protect them before Stage 01.

## Consequences

- Implementation work is isolated from `main` by default.
- Environment creation and protection rules remain a GitHub repository-admin
  action; this ADR documents the required settings.
- Stage 01 can safely bind OIDC federation to known environment names.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| GitFlow | More branches and release mechanics than the staged platform roadmap needs. |
| Direct commits to `main` | Too risky for platform infrastructure and policy changes. |
| Environment names per team | Team/workload isolation is introduced later through vending and Backstage workflows. |

## References

- [`plan/stages/stage-00-foundation.md`](../../plan/stages/stage-00-foundation.md)
- GitHub Environments documentation
