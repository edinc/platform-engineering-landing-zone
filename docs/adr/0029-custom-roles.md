# ADR-0029: Custom RBAC roles and group-only assignments

- Status: accepted
- Date: 2026-06-10
- Capability: connectivity & egress

## Context

The platform needs operational access for day-2 support without granting broad,
standing IAM powers. Azure built-in `Contributor` is operationally convenient
but includes too much blast radius if it is permanently active or assigned
directly to users. The repository also needs a repeatable way to prove that RBAC
created by this platform is group-based.

## Decision

**This repository creates Entra security groups and assigns Azure RBAC only to
those groups. It defines a custom `Platform Operator` role for operations without
IAM mutation and makes the default operator assignment PIM eligible.**

1. Platform groups are created as:
   - `pe-platform-admins`;
   - `pe-platform-operators`;
   - `pe-platform-readers`;
   - optional `pe-app-team-<name>` groups for team onboarding.
2. The default `Platform Operator - <environment>` custom role grants explicit
   management-plane operations for the platform resource families this repo owns,
   keeps network and Private Endpoint approval permissions read-only by default,
   and excludes
   Microsoft.Authorization write/delete/elevate actions plus credential retrieval
   actions. It deliberately avoids wildcard subscription-owner permissions. The
   environment and subscription suffix prevents custom-role name collisions when
   multiple stacks run in the same tenant.
3. Default access is:
   - `pe-platform-readers` receives active `Reader`;
   - `pe-platform-operators` receives PIM eligible `Platform Operator`;
   - privileged admin/Owner-style access is explicit input, not a default.
4. PIM activation requires MFA, justification, ticket information, and a maximum
   activation duration of 8 hours. Production activation requires approval by the
   configured approver group.
5. Management-group scoped assignments remain with the external ALZ owner unless
   a future ADR changes that boundary.

## Consequences

- RBAC changes are auditable in Terraform state and group membership, not hidden
  in individual user assignments.
- Operational users can perform platform repairs without receiving role
  assignment powers by default.
- PIM introduces operational friction, but that friction is intentional for
  privileged production access.
- Existing tenant IAM outside this repo is not modified; brownfield direct user
  assignments are detected by audit/reporting processes rather than silently
  removed by this stack.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Assign built-in Contributor directly to operators | Grants too much standing privilege and violates the group-only requirement. |
| Use only built-in Reader/Contributor/Owner | Cannot express "operate resources but do not mutate IAM" cleanly enough. |
| Let Backstage own group/RBAC state | Backstage initiates workflows but is not the source of truth for access control. |

## References

- [`infrastructure/terraform/identity/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/identity/)
- [Connectivity & egress](../how-it-works/connectivity-egress.md)
- [Azure custom roles](https://learn.microsoft.com/azure/role-based-access-control/custom-roles)
- [Microsoft Entra Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure)
