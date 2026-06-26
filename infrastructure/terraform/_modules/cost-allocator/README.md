# Cost allocator module

Stage 08 uses this module to run a nightly Python Azure Function that reads the
existing ALZ-owned Cost Management export container and publishes team/product
showback CSVs to a private output container.

The module intentionally uses managed identity for storage data-plane access:
the Function identity receives read access to the source export container and
write access to the showback container. The reference Function source lives in
`function_app/`.

## Function packaging

The Function package is built deterministically from `function_app/` by
`scripts/cost-allocator/package-function.sh` (also exposed as
`make cost-allocator-package`). The platform deploy workflow runs this
automatically before `terraform plan`/`apply` for the platform stack, so the
platform variable `cost_allocator_function_package_path` defaults to the build
output (`../_modules/cost-allocator/dist/function_app.zip`) and consumers do not
need to package by hand. Because Azure Functions remote build
(`SCM_DO_BUILD_DURING_DEPLOYMENT=true`) installs `requirements.txt` during
deployment, the ZIP only needs the Function source; it is byte-reproducible so
Terraform does not detect spurious changes between builds. For a local
`terraform plan`/`apply` with `enable_cost_allocator = true`, run
`make cost-allocator-package` first so the artifact exists (CI does this
automatically).

## Function deployment

The package is published with AAD-authenticated OneDeploy (`az webapp deploy
--type zip`), not the inline azurerm `zip_deploy_file` argument. The secure
landing zone disables SCM (webdeploy) and FTP basic publishing credentials, and
the module keeps them disabled (`ftp_publish_basic_authentication_enabled` and
`webdeploy_publish_basic_authentication_enabled` are both `false`). The inline
`zip_deploy_file` path only supports basic-auth publishing and runs during
Function App creation, so under this posture it fails with HTTP 401 and taints
the app on every apply. OneDeploy authenticates with the deploy principal's
Entra ID token instead, so it works with basic auth disabled.

OneDeploy requires a **Dedicated or Elastic Premium** plan. **Linux Consumption
(`Y1`) is not supported** when a package is supplied: Consumption only publishes
via run-from-package, and the secure host storage disables shared-key SAS. The
module enforces this with a precondition that rejects `Y1` + a package path. The
deploy step runs on the CI runner (or locally), which must be signed in to Azure
(the platform workflow uses OIDC) with publish rights on the Function App
(Contributor on the resource group is sufficient).

## Service plan profiles

The default service plan is EP1 with three zone-balanced workers and private
endpoints so production profiles have failover capacity and a private data
plane by default. The platform stack exposes these as overridable inputs:

| Profile | Inputs |
| --- | --- |
| Production (default) | `cost_allocator_public_network_access_enabled = false`, `cost_allocator_service_plan_sku_name = "EP1"`, `cost_allocator_service_plan_worker_count = 3`, `cost_allocator_service_plan_zone_balancing_enabled = true` |
| Cost-conscious demo (explicit exception) | `cost_allocator_public_network_access_enabled = true`, `cost_allocator_service_plan_sku_name = "B1"` (Basic, Dedicated), `cost_allocator_service_plan_worker_count = 1`, `cost_allocator_service_plan_zone_balancing_enabled = false` |

`B1` is the cost-conscious floor that still supports the secure AAD OneDeploy
publish path. Linux Consumption (`Y1`) is intentionally not offered for the demo
profile because it cannot be deployed under the disabled-basic-auth posture (see
[ADR-0057](../../../../docs/adr/0057-cost-allocator-aad-onedeploy.md)). The
module still neutralizes worker count and zone balancing for `Y1` so a
package-less `Y1` plan remains valid, and Function VNet integration plus
blob/queue/table private endpoints are only wired when
`public_network_access_enabled = false`.

## Inputs to supply

`enable_cost_allocator = true` requires `cost_export_storage_container_id`: the
full resource ID of the Cost Management export destination container. Bring an
existing ALZ-owned export, or provision one with the
`subscription-baseline` stack's `azurerm_subscription_cost_management_export`
(see [the FinOps cost-showback runbook](../../../../docs/runbooks/sre/cost-showback-failure.md)).
Cost Management exports produce their first file up to ~24h after creation.

The secure default profile (`cost_allocator_public_network_access_enabled =
false`) additionally requires the platform networking inputs it shares with the
rest of the stack: a `function-integration` entry in `subnet_address_prefixes`
for Function VNet integration, and `private_dns_zone_ids` covering
`privatelink.blob`, `privatelink.queue`, `privatelink.table`, and
`privatelink.azurewebsites` for the storage and Function private endpoints. The
cost-conscious public profile needs none of these — set
`cost_allocator_public_network_access_enabled = true` and omit
`function-integration`.
