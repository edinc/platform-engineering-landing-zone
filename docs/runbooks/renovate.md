# Runbook: Renovate dependency updates

This runbook operates Renovate as the primary dependency updater for GitHub
Actions, Terraform, containers, Helm, Kubernetes manifests, and later Backstage
packages.

Related decision: [ADR-0035](../adr/0035-dependency-updater-strategy.md).

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Renovate GitHub App installed | Opens dependency update pull requests. |
| `renovate.json` on `main` | Source of truth for update grouping and approvals. |
| Repository CI checks | Validate generated dependency PRs before merge. |
| GitHub vulnerability alerts | Native security alert signal; Dependabot version updates are not configured. |

## 1. Install Renovate

Install the Renovate GitHub App on `platform-engineering-landing-zone`. Grant it
access to this repository and, later, generated golden-path repositories that
should inherit the same dependency policy.

Confirm the first onboarding PR references [`renovate.json`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/renovate.json)
and does not propose a second config file.

## 2. Triage the dependency dashboard

1. Open the Renovate dependency dashboard issue.
2. Approve major updates only after reading the release notes and checking the
   owning stage or ADR.
3. Keep platform automerge disabled. Merge after CI and human review pass.
4. Use GitHub-native Dependabot/security alerts for active vulnerabilities;
   Renovate vulnerability-alert PRs are disabled to avoid duplicate security PRs.

## 3. Review update PRs

For each PR:

1. Confirm the manager and labels match the affected surface (`terraform`,
   `helm`, `container`, or `github-actions`).
2. Review release notes for breaking changes, new permissions, or new network
   egress needs.
3. Run the same validation expected for a manual change to that surface.
4. For base-image updates, confirm downstream image builds still produce signed
   images and SBOMs.

## 4. Emergency vulnerability updates

For critical CVEs:

1. Prioritize the Renovate PR or trigger a manual Renovate run.
2. If no PR exists, patch manually and leave Renovate to converge the version
   afterward.
3. Record any temporary scanner exception in the release PR and remove it after
   the patched version is deployed.

## Rollback

Revert the dependency PR and rerun the relevant repository checks. For promoted
images, follow [release rollback](release.md#rollback) so cluster-state returns
to a previously signed digest.
