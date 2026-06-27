# Team onboarding Terraform (multi-tenancy & onboarding)

This stack owns the per-team identity and GitHub objects created by the
`onboard-team` Backstage template.

Related decisions: [ADR-0018](../../../docs/adr/0018-inner-loop.md),
[ADR-0043](../../../docs/adr/0043-ownership-matrix.md), and the [team onboarding runbook](../../../docs/runbooks/team-onboarding.md)
for multi-tenancy & onboarding.

## What this stack owns

| Capability | Resource | Notes |
| --- | --- | --- |
| App-team identity | `azuread_group` | Creates `pe-app-team-<team>` with duplicate-name prevention. |
| App-team GitHub group | `github_team` | Creates `app-team-<team>` or the requested compatible team slug. |
| Default repository access | `github_team_repository` | Grants only explicitly requested `pull` or `triage` permissions for workflow-approved repositories. |

## State backend

State lives in the Azure foundation account, container `team-onboarding`, with one key
per team:

```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=request.auto.tfvars.json
```

CI validates credential-free with `terraform init -backend=false`.

## Idempotency

The stack uses deterministic names and `prevent_duplicate_names = true`. If a
brownfield Entra group or GitHub team already exists, import it before the first
apply instead of creating a duplicate:

```bash
terraform import azuread_group.app_team <entra-group-object-id>
terraform import github_team.app_team <github-team-id>
```

Self-service requests cannot grant `push`, `maintain`, or `admin`. Those changes
must use the repository owner approval path outside team onboarding.
