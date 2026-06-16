module "cost_allocator" {
  count = var.enable_cost_allocator ? 1 : 0

  source = "../_modules/cost-allocator"

  name_prefix                            = local.name_prefix
  resource_group_name                    = azurerm_resource_group.platform.name
  location                               = azurerm_resource_group.platform.location
  cost_export_storage_container_id       = var.cost_export_storage_container_id
  cost_export_root_folder                = var.cost_export_root_folder
  function_package_path                  = var.cost_allocator_function_package_path
  public_network_access_enabled          = var.cost_allocator_public_network_access_enabled
  virtual_network_subnet_id              = var.enable_cost_allocator ? azurerm_subnet.platform["function-integration"].id : ""
  private_endpoint_subnet_id             = var.enable_private_endpoints && !var.cost_allocator_public_network_access_enabled ? local.private_endpoint_subnet_id : ""
  private_dns_zone_ids                   = var.private_dns_zone_ids
  application_insights_connection_string = var.cost_allocator_application_insights_connection_string
  tags                                   = local.tags
}

resource "azurerm_role_assignment" "backstage_cost_showback_reader" {
  count = local.backstage_enabled ? 1 : 0

  scope                = local.backstage_cost_showback_container_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.backstage_workload_identity_principal_id
  principal_type       = "ServicePrincipal"
}
