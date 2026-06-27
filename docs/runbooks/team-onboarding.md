# Team onboarding runbook

Capability: multi-tenancy, onboarding, and ownership

Use this runbook when onboarding an application team through the Backstage
`onboard-team` template or by submitting a `TeamOnboardingRequest` directly.

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Identity stack | Provides the Entra tenant and group conventions. |
| Namespace vending | Creates workload identities, namespace RBAC, and cluster-state PRs. |
| Backstage | Hosts the `onboard-team` template and syncs Entra groups. |
| Protected `vending` environment | Gates Terraform apply and namespace vending PR creation. |
| `PLATFORM_GITHUB_ADMIN_TOKEN` secret | Allows the GitHub provider to create organization teams, explicit repo permissions, and generated namespace PRs. |
| `TEAM_ONBOARDING_APPROVED_REPOSITORIES` variable | Comma-separated repository names that team onboarding may grant `pull` or `triage` permissions on; defaults to this repo when omitted. |

## Request

The Backstage template collects:

| Field | Rule |
| --- | --- |
| Team name | Lowercase slug; becomes `pe-app-team-<name>` and `app-team-<name>`. |
| Product name | Lowercase product slug used in tags, catalog, and namespace names. |
| Cost center | `cc-...` value approved by FinOps. |
| On-call rotation ID | PagerDuty/OpsGenie/incident-management rotation identifier. |
| GitHub team | Must equal `app-team-<team name>`; exceptions require a separate platform-admin change path, not self-service onboarding. |
| Data classification | `public`, `internal`, `confidential`, or `restricted`. |

The template opens a PR under `vending/requests/teams/`. The
`onboard-team.yml` workflow validates the request and Terraform stack on PRs.

## Apply

After the request PR merges to `main`, the protected workflow:

1. Applies `infrastructure/terraform/team-onboarding` with a deterministic state
   key `teams/<team>/terraform.tfstate`.
2. Creates or imports the Entra group `pe-app-team-<team>`.
3. Creates or imports the GitHub team `app-team-<team>`.
4. Grants only explicit `pull` or `triage` repository permissions from the
   request, and only for repositories listed in the protected
   `TEAM_ONBOARDING_APPROVED_REPOSITORIES` variable.
5. Opens a namespace vending PR for every requested environment using an
   environment-unique namespace name `<team>-<product>-<environment>` and
   the immutable `entraGroupObjectId` output from Terraform.
   The generated namespace request intentionally contains no Key Vault secret
   grants; teams request secret access later through a reviewed namespace/service
   golden path.
6. A platform admin updates Backstage RBAC configuration by adding the new group
   ref to `backstage_application_team_group_refs` and adding
   `"group:default/pe-app-team-<team>": "<team>"` to
   `backstage_application_team_group_map_json`, then re-applies the Backstage
   Backstage Flux configuration. Until this manual step is reconciled, the team
   group exists but cannot execute team-scoped templates.

## Idempotency contract

Every step is independently re-runnable:

| Step | Idempotency behavior | Recovery |
| --- | --- | --- |
| Entra group | Terraform name is deterministic and duplicate names are prevented. | Import an existing group into the team state if it already exists. |
| GitHub team | Terraform owns one closed team slug. | Import an existing team before apply or update the request slug. |
| Backstage group | Microsoft Graph reconciles the Entra group. | Confirm the group object ID is in the configured Graph filter, then wait for the provider schedule. |
| Backstage RBAC map | Platform Terraform/Flux substitutes the group refs and group-to-team map into `backstage-rbac-groups`. | Re-apply the Backstage configuration after adding the group ref and map entry. |
| Namespace request PR | Workflow branch includes the run ID and can be re-created. | Re-run the workflow after fixing protected variables or request data. |
| Cost showback | Tags and group-to-team mappings are generated from the same team slug. | Re-run cost allocation after tags appear in Cost Management exports. |

Partial failures should be fixed by correcting the request, importing brownfield
objects, or re-running the protected workflow. Do not create groups, namespace
RBAC, or cost metadata manually in the Azure or GitHub portals.

## Smoke test

Before enabling golden paths for a tenant, run:

```bash
scripts/test/onboarding-smoke.sh
```

Set `ONBOARDING_SMOKE_AZURE=true` plus the documented environment variables in the
script to perform read-only Azure checks against deployed Backstage and onboarding
prerequisites.
