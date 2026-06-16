# ADR-0042: Store TechDocs in private Azure Blob Storage

- Status: accepted
- Date: 2026-06-15
- Stage: Stage 09 - Backstage MVP

## Context

TechDocs should use the recommended publisher flow: build documentation in CI and
serve published static content from Backstage. The storage location must support
private networking, managed identity, and CI publisher RBAC.

## Decision

Provision a dedicated Azure Storage account and private `techdocs` container from
the platform Terraform stack. Disable shared keys and public network access,
enable Blob versioning and retention, attach a Blob private endpoint, and grant
`Storage Blob Data Reader` at container scope to the Backstage managed identity.
Configured Stage 06 publisher principals receive `Storage Blob Data Contributor`
so documentation publishing remains CI-owned.

## Consequences

- Backstage and CI use Azure AD/RBAC instead of storage keys.
- The portal runtime can read published docs but cannot overwrite or delete them.
- Private endpoint DNS is required before enabling TechDocs storage.
- CI publishers must run from a VNet-integrated runner when the storage account
  is private.
- CMK can be added later when the platform storage key lifecycle is standardized.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Local filesystem publisher | Not HA and loses data on pod replacement. |
| S3-compatible storage | Adds non-Azure dependencies to an Azure-native platform. |
| Public blob endpoint | Conflicts with private-by-default platform posture. |

## References

- [`infrastructure/terraform/platform/techdocs.tf`](../../infrastructure/terraform/platform/techdocs.tf)
- [`workflows/techdocs-publish.yml`](../../workflows/techdocs-publish.yml)
