resource "azurerm_container_app_environment" "platform" {
  count = var.enable_aca_environment ? 1 : 0

  name                               = "cae-${local.name_prefix}"
  location                           = azurerm_resource_group.platform.location
  resource_group_name                = azurerm_resource_group.platform.name
  infrastructure_resource_group_name = "rg-${local.name_prefix}-aca-infra"
  infrastructure_subnet_id           = azurerm_subnet.platform["aca-infra"].id
  internal_load_balancer_enabled     = true
  public_network_access              = "Disabled"
  logs_destination                   = var.log_analytics_workspace_id != "" ? "log-analytics" : "azure-monitor"
  log_analytics_workspace_id         = var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : null
  zone_redundancy_enabled            = var.profile == "prod" && length(var.availability_zones) > 1
  tags                               = local.tags

  dynamic "workload_profile" {
    for_each = local.aca_workload_profiles

    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }

  depends_on = [azurerm_subnet_route_table_association.egress]
}
