resource "azurerm_private_endpoint" "this" {
  for_each = var.private_endpoints

  name                = "pe-${each.key}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  subnet_id           = azurerm_subnet.hub["private-endpoints"].id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${each.key}-${var.location_short}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = each.value.manual_approval
    request_message                = each.value.manual_approval && each.value.request_message != "" ? each.value.request_message : null
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      for zone_name in each.value.private_dns_zone_names : azurerm_private_dns_zone.this[zone_name].id
    ]
  }
}

resource "azurerm_private_endpoint" "ampls" {
  for_each = var.enable_monitor_private_link_scope ? { main = true } : {}

  name                = "pe-${local.name_prefix}-ampls"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  subnet_id           = azurerm_subnet.hub["private-endpoints"].id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${local.name_prefix}-ampls"
    private_connection_resource_id = azurerm_monitor_private_link_scope.ampls["main"].id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      for zone_name in local.monitor_private_dns_zone_names : azurerm_private_dns_zone.this[zone_name].id
    ]
  }
}
