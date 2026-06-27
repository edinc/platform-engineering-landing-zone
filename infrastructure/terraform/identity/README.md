# Identity (connectivity & egress)

Entra group primitives, group-only Azure RBAC, the `Platform Operator` custom
role, and PIM policy/eligibility for the platform subscription boundary.

Related decision: [ADR-0029](../../../docs/adr/0029-custom-roles.md).

## What this stack owns

| Capability | Resource | Notes |
|------------|----------|-------|
| Platform groups | `azuread_group` | `pe-platform-admins`, `pe-platform-operators`, and `pe-platform-readers`. |
| App-team groups | `azuread_group` | Optional `pe-app-team-<name>` groups from `app_team_names`. |
| Custom role | `azurerm_role_definition` | Environment-specific `Platform Operator` role with explicit platform resource-family permissions, read-only network visibility, and no IAM/credential mutation. |
| Default RBAC | `azurerm_role_assignment` | Reader for platform readers; Platform Operator active only when PIM is disabled. |
| PIM | `azurerm_role_management_policy`, `azurerm_pim_eligible_role_assignment` | Max 8h activation, MFA and ticket/justification required, approval required for prod. |

## What this stack deliberately does not own

- Management-group scoped assignments owned by the external ALZ.
- Direct user RBAC assignments; all inputs select a group key.
- Workload Identity federation credentials; platform shared services records AKS issuer details
  and GitOps platform applies per-service-account federation.
- Sentinel routing for PIM alerts; observability integration is completed by
  observability, SRE & FinOps.

## State backend

State lives in the Azure foundation account, container `identity`, with a key such as
`nonprod/identity.tfstate`. Copy `backend.hcl.example` to `backend.hcl`, fill
`resource_group_name` and `storage_account_name` from `_bootstrap` outputs, then:

```bash
terraform init -backend-config=backend.hcl
```

CI validates credential-free with `terraform init -backend=false`.

## Group keys

Role assignment inputs reference group keys instead of object IDs:

| Key | Display name |
|-----|--------------|
| `platform_admins` | `pe-platform-admins` |
| `platform_operators` | `pe-platform-operators` |
| `platform_readers` | `pe-platform-readers` |
| `app_team_<name>` | `pe-app-team-<name>` with hyphens replaced by underscores in the key |

This keeps the Terraform interface group-only and prevents accidental direct user
assignments from this repo.

## Brownfield adoption

If the platform groups already exist, import them before the first apply instead
of disabling `prevent_duplicate_names`:

```bash
terraform import 'azuread_group.this["platform_admins"]' <group-object-id>
terraform import 'azuread_group.this["platform_operators"]' <group-object-id>
terraform import 'azuread_group.this["platform_readers"]' <group-object-id>
```

The `Platform Operator` custom role name defaults to `Platform Operator -
<environment> - <subscription-prefix>` to avoid custom-role display-name
collisions when multiple environment stacks target the same tenant. Set
`platform_operator_role_name` only when intentionally sharing a singleton role and
assignable scope set.

## Validation

```bash
make terraform-validate
```

## Acceptance-criteria mapping

| # | Criterion | Where |
|---|-----------|-------|
| 5 | RBAC created by this repo is group-only | Role assignment variables use `group_key`; resources set `principal_type = "Group"`. |
| 6 | PIM activation policy exists | `pim.tf` configures max duration, MFA, ticket/justification, and prod approval. |
| Capability deliverable | Custom role documented | `rbac.tf` and ADR-0029. |
