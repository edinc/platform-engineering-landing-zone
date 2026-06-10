resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zone_names

  name                = each.value
  resource_group_name = azurerm_resource_group.connectivity.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_vnet_links

  name                  = "lnk-${each.value.vnet_key}-${substr(sha1(each.value.zone_name), 0, 8)}"
  resource_group_name   = azurerm_resource_group.connectivity.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone_name].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_monitor_private_link_scope" "ampls" {
  for_each = var.enable_monitor_private_link_scope ? { main = true } : {}

  name                = "ampls-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.connectivity.name

  ingestion_access_mode = var.monitor_private_link_ingestion_access_mode
  query_access_mode     = var.monitor_private_link_query_access_mode
  tags                  = local.tags
}

resource "azurerm_monitor_private_link_scoped_service" "this" {
  for_each = var.enable_monitor_private_link_scope ? {
    for resource_id in var.monitor_linked_resource_ids : substr(sha1(resource_id), 0, 12) => resource_id
  } : {}

  name                = "amplss-${each.key}"
  resource_group_name = azurerm_resource_group.connectivity.name
  scope_name          = azurerm_monitor_private_link_scope.ampls["main"].name
  linked_resource_id  = each.value
}
