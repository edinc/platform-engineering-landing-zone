# ADR-0014: Terraform remote state model

- Status: accepted
- Date: 2026-06-09
- Capability: Azure foundation

## Context

Every later capability runs Terraform from GitHub Actions and needs durable, locked,
encrypted remote state. State for a platform landing zone is highly sensitive:
it contains resource identifiers, configuration, and occasionally secret
material. The state backend is the first thing that must exist ("turtles all the
way down"), before any OIDC identity or higher-level infrastructure.

We need a backend that is Azure-native, supports state locking, encrypts at rest
with a customer-managed key, authenticates without long-lived storage keys, and
cleanly separates state per capability and per environment profile.

## Decision

Terraform state uses the **AzureRM backend** backed by a single dedicated
storage account (`stpetf<loc><suffix>`) in a dedicated resource group
(`rg-pe-tfstate-<loc>`):

- **One blob container per capability** plus per-profile environment containers
  (`bootstrap`, legacy `alz`, `subscription-baseline`, `connectivity`, ...
  `envs-demo`, `envs-nonprod`, `envs-prod`). Each capability's state key lives in its
  own container for blast-radius isolation and least-privilege scoping. The
  legacy `alz` container is retained so existing bootstrap deployments cannot
  accidentally delete a state container during the subscription baseline rename.
- **Locking** uses native blob leases (the AzureRM backend default). Terragrunt
  is not used.
- **Resilience**: RA-GRS replication, blob versioning, soft delete, and change
  feed protect state history.
- **Encryption**: a customer-managed key (RSA 3072) in the seed Key Vault, with
  an automatic rotation policy, accessed through a user-assigned identity.
  Infrastructure (double) encryption is enabled on the account.
- **Identity-only data plane**: `shared_access_key_enabled = false`; the backend
  and provider authenticate with Entra ID (`use_azuread_auth`,
  `storage_use_azuread`). There are no storage account keys to leak or rotate.
- Backend settings are supplied at init time with `-backend-config=backend.hcl`,
  so no tenant-specific values are committed.
- State containers have `prevent_destroy = true`; removal requires an explicit,
  reviewed state-migration change after confirming no live state blobs remain.

The state account is created by `bootstrap-init.sh` and then **adopted** into
Terraform via a scripted `make bootstrap-import` (alongside its resource group,
the bootstrap container, and the seed Key Vault). The first Terraform apply
reconciles those adopted resources **in place** and creates the remaining
bootstrap resources (CMK, identity, additional state containers, firewall
baseline, monitoring); applies after that are drift-only. Immutable, create-time
account properties — notably infrastructure (double) encryption — are set by the
script to match this configuration exactly, so adoption never triggers a
destroy/recreate of the account that stores state.

## Consequences

- The first state blobs written during the very first apply are platform-managed
  encrypted; customer-managed key encryption applies once the CMK association is
  created in the same apply. This one-time gap is documented in the runbook.
- Disabling shared keys means all tooling (CI, local) must use Entra ID auth and
  hold the appropriate data-plane role (`Storage Blob Data Contributor`).
- Per-capability containers let each deploy identity be scoped to only its own
  state path in later capabilities.
- Purge protection on the seed Key Vault means the CMK and vault name cannot be
  hard-deleted; name reuse recovers the soft-deleted vault.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Terraform Cloud / HCP | Adds an external control plane and egress dependency; the platform standard is Azure-native state. |
| Terragrunt for state config | Extra tooling and indirection; native backend config plus per-container keys meets the need. |
| Single shared container, key-per-capability | Weaker isolation; per-container scoping enables least-privilege state access later. |
| Storage account keys for auth | Long-lived secrets that contradict the secret-zero goal. |

## References

- [Azure foundation](../how-it-works/foundation.md)
- [`infrastructure/terraform/_bootstrap`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/_bootstrap)
- [ADR-0025: OIDC federation policy](0025-oidc-federation.md)
- [`docs/runbooks/bootstrap.md`](../runbooks/bootstrap.md)
