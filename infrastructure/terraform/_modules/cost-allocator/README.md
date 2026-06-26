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
Terraform does not detect spurious changes between builds.

## Service plan profiles

The default service plan is EP1 with three zone-balanced workers and private
endpoints so production profiles have failover capacity and a private data
plane by default. The platform stack exposes these as overridable inputs:

| Profile | Inputs |
| --- | --- |
| Production (default) | `cost_allocator_public_network_access_enabled = false`, `cost_allocator_service_plan_sku_name = "EP1"`, `cost_allocator_service_plan_worker_count = 3`, `cost_allocator_service_plan_zone_balancing_enabled = true` |
| Cost-conscious demo (explicit exception) | `cost_allocator_public_network_access_enabled = true`, `cost_allocator_service_plan_sku_name = "Y1"` (Consumption), `cost_allocator_service_plan_worker_count = 1`, `cost_allocator_service_plan_zone_balancing_enabled = false` |

The module neutralizes the worker count and zone balancing automatically for the
`Y1` Consumption plan, and Function VNet integration plus blob/queue/table
private endpoints are only wired when `public_network_access_enabled = false`.

## Inputs to supply

`enable_cost_allocator = true` requires `cost_export_storage_container_id`: the
full resource ID of the Cost Management export destination container. Bring an
existing ALZ-owned export, or provision one with the
`subscription-baseline` stack's `azurerm_subscription_cost_management_export`
(see [the FinOps cost-showback runbook](../../../../docs/runbooks/sre/cost-showback-failure.md)).
Cost Management exports produce their first file up to ~24h after creation.
