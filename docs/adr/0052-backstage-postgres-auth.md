# ADR-0052: Prefer Entra passwordless auth for Backstage Postgres

- Status: accepted
- Date: 2026-06-15
- Stage: Stage 09 - Backstage MVP

## Context

Stage 04 creates the `backstage` database on PostgreSQL Flexible Server with
private networking. Stage 09 needs Backstage to connect without committing or
storing long-lived database credentials where possible.

## Decision

Prefer PostgreSQL Flexible Server Entra authentication using the Backstage
Workload Identity. Backstage obtains an Entra access token at runtime and uses it
as the database password for the mapped Postgres principal.

The deployment includes a runtime launcher that can exchange the pod's federated
token for the PostgreSQL Entra scope before starting the Backstage backend. The
Terraform-managed PostgreSQL Flexible Server still defaults to password auth
until Entra admin/user mapping is configured, so `backstage_postgres_auth_mode`
defaults to `password`. Keep the fallback Secrets Store CSI path for the
Key Vault-stored Postgres password visible and rotate it through Renovate or the
platform secret rotation process.

## Consequences

- The preferred path removes static database passwords from Backstage runtime
  configuration once Postgres Entra auth is configured.
- Postgres identity setup is an explicit prerequisite before switching
  `backstage_postgres_auth_mode` to `entra`.
- The default fallback path remains visible and rotatable until that prerequisite
  is met.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Always use a Postgres password | Simpler but conflicts with managed identity defaults. |
| Store password in Backstage app config | Secret material would enter git or image layers. |
| Run an in-cluster Postgres | Conflicts with Stage 04 managed PaaS ownership. |

## References

- [`infrastructure/terraform/platform/postgres.tf`](../../infrastructure/terraform/platform/postgres.tf)
- [`platform-gitops/clusters/_base/addon-config/backstage/secretproviderclass.yaml`](../../platform-gitops/clusters/_base/addon-config/backstage/secretproviderclass.yaml)
