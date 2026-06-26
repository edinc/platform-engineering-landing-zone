# Runbook: cost showback failure

## Trigger

`CostShowbackExportStale` fires when the cost allocator has not published a
showback CSV within the expected daily window.

## Triage

1. Check the Cost Management export status with `az costmanagement export show`.
2. Confirm new CSV blobs exist in the ALZ-owned export container.
3. Check the cost allocator Function App health and latest invocation logs.
4. Verify the Function managed identity still has Storage Blob Data Reader on
   the export container and Storage Blob Data Contributor on the showback
   container.

## Mitigation

1. Re-run the Function after the source export is available.
2. Restore missing RBAC assignments through Terraform; do not grant account keys.
3. If the export path changed, update Terraform variables and run a plan before
   applying.
4. Charge unallocated or malformed-tag rows to `platform-overhead` until source
   tagging is corrected.

## Recovery

1. Confirm a new `showback/YYYY/MM/DD/team-showback.csv` exists.
2. Confirm rows aggregate by `costCenter`, `team`, and `product`.
3. Link any persistent tagging gaps to the owning team.

## Enabling the allocator

The cost allocator is disabled by default (`enable_cost_allocator = false`). To
turn it on for a profile:

1. Ensure a Cost Management export destination container exists and set
   `cost_export_storage_container_id` to its full resource ID. Provision the
   export with the `subscription-baseline` stack's
   `azurerm_subscription_cost_management_export`, or point at an existing
   ALZ-owned export. First export data appears up to ~24h after creation.
2. Set `enable_cost_allocator = true`. The Function package is built
   automatically by the platform deploy (`make cost-allocator-package` locally);
   `cost_allocator_function_package_path` defaults to that artifact.
3. Pick a service-plan profile. Production keeps the secure EP1 default, which
   additionally requires a `function-integration` entry in
   `subnet_address_prefixes` and `private_dns_zone_ids` for the blob, queue,
   table, and azurewebsites private endpoints. A cost-conscious demo may instead
   set `cost_allocator_public_network_access_enabled = true`,
   `cost_allocator_service_plan_sku_name = "B1"`,
   `cost_allocator_service_plan_worker_count = 1`, and
   `cost_allocator_service_plan_zone_balancing_enabled = false` as a documented
   cost exception, and may omit `function-integration` and the private DNS zones.
   `B1` (Basic, Dedicated) is the cheapest plan that still supports the secure
   AAD OneDeploy publish path; Linux Consumption (`Y1`) is not supported with a
   package (see ADR-0057) and the module rejects it with a precondition.
4. Apply the platform stack, then redeploy Backstage so
   `costInsights.azure.showbackContainerUrl` (sourced from the module output)
   reaches the running config. Backstage's workload identity receives Storage
   Blob Data Reader on the showback container automatically.

## Function deploy fails with HTTP 401 / "API isn't available in this environment"

The module publishes the package with AAD-authenticated OneDeploy
(`az webapp deploy --type zip`) and keeps SCM/FTP basic publishing credentials
disabled, matching the landing-zone posture.

- **`401 Unauthorized` publishing the zip** means something reintroduced the
  inline azurerm `zip_deploy_file` path (basic auth), which the landing zone
  blocks. Confirm `terraform_data.function_deploy` owns the publish and that the
  Function App has `ftp_publish_basic_authentication_enabled = false` and
  `webdeploy_publish_basic_authentication_enabled = false`.
- **`This API isn't available in this environment yet!`** means the plan is Linux
  Consumption (`Y1`), which does not support OneDeploy. Use a Dedicated (`B1`) or
  Elastic Premium (`EP1`) plan.
- **OneDeploy 403** means the deploy principal lacks publish rights. The CI
  runner must be signed in to Azure (OIDC) with at least Contributor on the
  Function App's resource group.
