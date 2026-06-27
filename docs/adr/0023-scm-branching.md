# ADR-0023: Use GitHub with trunk-based short-lived branches

- Status: accepted
- Date: 2026-06-09
- Capability: repository foundation

## Context

The platform repository needs a source-control model that supports rapid
iteration while protecting shared infrastructure, policy, and workflow changes.
The repository foundation also establishes GitHub Environments used later by OIDC federation,
deployment approvals, and image-promotion protection.

## Decision

Use GitHub as the SCM and `main` as the protected trunk branch. Contributors and
automation must create or switch to a task-specific feature branch before
starting implementation work unless the user explicitly requests direct work on
`main`.

Pull requests into `main` require:

- Roadmap-aligned scope and validation evidence.
- CODEOWNERS review from the relevant ownership route when a valid reviewer is
  available.
- Passing repository foundation quality-gate workflows.
- Independent correctness, security, and architecture review passes before
  final handoff.

The importable repository ruleset is stored at
`.github/rulesets/main-branch-protection.json` and requires the repository foundation quality
gate and Backstage CI stub status checks before merge. It intentionally does
not enforce code-owner approval while this repository is user-owned, because the
current fallback owner could otherwise make pull requests unmergeable. Enable
required code-owner approval after adding at least one independent reviewer or
moving the repository under an organization with the documented teams.

This repository is currently owned by the `edinc` user account, so CODEOWNERS
uses `@edinc` as the enforceable owner while comments document the intended
organization team routes. If the repository moves under an organization, replace
the fallback owner with the documented teams before enforcing code-owner review.

Define these GitHub Environments for downstream capabilities:

| Environment | Purpose | Protection guidance |
|-------------|---------|---------------------|
| `bootstrap` | Azure foundation remote state, OIDC federation, seed Key Vault, and secret-zero setup. | Platform infrastructure and security reviewers. |
| `dev` | First integration target for platform and golden-path changes. | Platform maintainers; short approval path. |
| `nonprod` | Pre-production validation for platform workflows and workload onboarding. | Platform infrastructure and security reviewers. |
| `prod` | Production platform operations. | Required platform, security, and operations reviewers. |

The environments are referenced by the repository foundation Backstage CI stub so repository
administrators can create and protect them before Azure foundation.

## Consequences

- Implementation work is isolated from `main` by default.
- Environment creation and protection rules remain a GitHub repository-admin
  action; this ADR documents the required settings.
- Azure foundation can safely bind OIDC federation to known environment names.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| GitFlow | More branches and release mechanics than the platform roadmap needs. |
| Direct commits to `main` | Too risky for platform infrastructure and policy changes. |
| Environment names per team | Team/workload isolation is introduced later through vending and Backstage workflows. |

## References

- [Repository foundation roadmap](../roadmap/README.md)
- GitHub Environments documentation
