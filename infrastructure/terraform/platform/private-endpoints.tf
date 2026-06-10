resource "azurerm_private_endpoint" "platform" {
  for_each = local.private_endpoint_specs

  name                = "pe-${local.name_prefix}-${each.key}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = local.private_endpoint_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${local.name_prefix}-${each.key}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      for zone_name in each.value.private_dns_zone_names : var.private_dns_zone_ids[zone_name]
    ]
  }
}
