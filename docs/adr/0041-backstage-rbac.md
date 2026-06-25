# ADR-0041: Backstage RBAC uses dynamic Entra group mappings

- Status: accepted
- Date: 2026-06-15
- Stage: Stage 09 - Backstage MVP

## Context

Backstage permissions must reflect Entra ID group membership without requiring a
code change for every onboarded application team in Stage 10.

## Decision

Use the Backstage Permission Framework with group references resolved from
configuration. The Kubernetes `backstage-rbac-groups` ConfigMap feeds runtime
environment variables that Backstage resolves into `permission.rbac.*`. The
policy code reads the platform admin group, platform operator group, and explicit
application-team group allowlist from configuration and evaluates permissions
against `ownershipEntityRefs` from the signed-in identity.

GitHub catalog discovery is intentionally limited to non-identity entity kinds.
`User` and `Group` entities must come from Microsoft Graph or static
platform-owned configuration so repository writers cannot mint privileged
Backstage identities.

Microsoft Graph ingestion runs under the Backstage workload identity service
principal. The platform Terraform stack exports that identity's client ID as
`platform_workload_identity_client_ids.backstage` and principal ID as
`platform_workload_identity_principal_ids.backstage`, but does not grant Microsoft Graph
application permissions because doing so would require broad tenant-level Graph
write privileges for the deploy identity. Operators must grant read-only Graph
application roles
(`User.Read.All`, `Group.Read.All`, and `GroupMember.Read.All`) to the Backstage
workload identity service principal after the platform stack is applied. The
Backstage workload identity service principal is the identity used by the catalog
Microsoft Graph provider.

In short: grant Microsoft Graph read permissions to the Backstage workload identity service principal.

Admins receive all permissions. Operators can write catalog data, execute
scaffolder actions, and view Kubernetes. Application teams can read catalog data,
write their own catalog entities conditionally, and execute scaffolder actions.
Direct `kubernetes.*` Backstage permissions remain operator-only until Stage 10
generates namespace-scoped RoleBindings for onboarded teams.

## Consequences

- Stage 10 onboarding can add Entra groups without Backstage code changes.
- Delete operations stay admin-only and auditable.
- The policy file remains deterministic and testable without embedding
  tenant-specific group names.
- Tenant setup must include the read-only Microsoft Graph app-role grants for
  the Backstage workload identity before users can resolve during sign-in.
- Application-team Kubernetes self-service requires Stage 10 namespace-scoped
  RBAC before it is enabled in the portal.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Hard-coded group names in policy code | Creates code changes for onboarding and tenant drift. |
| Backstage read-only MVP | Blocks golden-path and ownership workflows. |
| Separate authorization proxy | Adds another control plane before MVP usage justifies it. |

## References

- [`policies/backstage/permissions.ts`](../../policies/backstage/permissions.ts)
- [`docs/adr/0025-oidc-federation.md`](0025-oidc-federation.md)
- [`plan/stages/stage-09-backstage-mvp.md`](../../plan/stages/stage-09-backstage-mvp.md)
