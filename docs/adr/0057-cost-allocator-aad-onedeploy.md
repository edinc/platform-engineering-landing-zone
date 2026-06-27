# ADR-0057: Cost allocator Function publishes via AAD OneDeploy

- Status: accepted
- Date: 2026-06-26
- Capability: observability, SRE & FinOps

## Context

The cost allocator for observability, SRE & FinOps runs a Python Azure Function (see the
`cost-allocator` module). The secure landing zone disables SCM (webdeploy) and
FTP basic publishing credentials on App Service / Functions
(`basicPublishingCredentialsPolicies` `allow = false`).

The azurerm `azurerm_linux_function_app.zip_deploy_file` argument publishes the
package over the SCM ZipDeploy endpoint using **basic auth**, and it runs during
Function App creation. Under the disabled-basic-auth posture this fails with
`401 Unauthorized`, which taints the resource so Terraform destroys and
recreates the Function App on every apply — an unrecoverable loop. Linux
Consumption (`Y1`) cannot escape this either: it only publishes via
run-from-package, and the module's host storage disables shared-key SAS, so a
package URL cannot be minted.

## Decision

The module keeps basic publishing credentials disabled
(`ftp_publish_basic_authentication_enabled = false`,
`webdeploy_publish_basic_authentication_enabled = false`) and publishes the
package with **AAD-authenticated OneDeploy**:

1. The platform deploy workflow builds the deterministic package
   (`scripts/cost-allocator/package-function.sh`) before `terraform plan`/`apply`.
2. Terraform creates the Function App without an inline `zip_deploy_file`, so the
   create step never attempts a basic-auth publish.
3. A `terraform_data.function_deploy` resource runs `az webapp deploy --type zip`
   after the app exists. OneDeploy authenticates with the deploy principal's
   Entra ID token (the CI runner's OIDC login), so it succeeds with basic auth
   disabled. The publish re-runs only when the package hash or Function App id
   changes.
4. Azure Functions remote build (`SCM_DO_BUILD_DURING_DEPLOYMENT = true`) keeps
   the package source-only.

OneDeploy requires a **Dedicated or Elastic Premium** plan. Linux Consumption
(`Y1`) is therefore unsupported with a package, and the module enforces this with
a precondition. The cost-conscious demo profile uses **`B1` (Basic, Dedicated)**,
the cheapest plan that keeps the secure publish path.

## Consequences

- Cost allocator deploys are reproducible and keep the landing-zone
  disabled-basic-auth posture; no basic-auth exception is introduced.
- The publish uses a `local-exec` provisioner, accepting a documented imperative
  step (consistent with ADR-0053's CI-push pattern for non-Flux Azure resources)
  rather than the declarative `zip_deploy_file` argument.
- The demo floor moves from `Y1` (~$0 idle) to `B1` (~$13/mo continuous). The
  trade is a clean, secure, reproducible publish with no SAS secrets or basic
  auth.
- The deploy principal needs publish rights on the Function App (Contributor on
  the resource group is sufficient); the platform workflow already runs as such.

## Alternatives considered

| Alternative | Reason not chosen |
| --- | --- |
| Re-enable SCM basic auth so `zip_deploy_file` works | Reverses the landing-zone security posture for every cost-allocator deploy; the recreate loop also resets it. |
| `WEBSITE_RUN_FROM_PACKAGE` with a SAS URL on `Y1` | Requires a shared-key storage account and a long-lived SAS secret in app settings, and vendored dependencies (no remote build). |
| Identity-based `WEBSITE_RUN_FROM_PACKAGE` | Not supported on Linux Consumption, and adds blob-data-plane RBAC for the deploy principal. |
| Keep `Y1` and accept manual publishes | Not reproducible; defeats the templatized goal. |

## References

- [`infrastructure/terraform/_modules/cost-allocator/`](https://github.com/edinc/platform-engineering-landing-zone/tree/main/infrastructure/terraform/_modules/cost-allocator/)
- [`docs/runbooks/sre/cost-showback-failure.md`](../runbooks/sre/cost-showback-failure.md)
- [`docs/adr/0053-aca-gitops-exception.md`](0053-aca-gitops-exception.md)
- [observability, SRE & FinOps](../how-it-works/observability-sre-finops.md)
