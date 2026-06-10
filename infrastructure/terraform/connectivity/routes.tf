resource "azurerm_route_table" "firewall_egress" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name                          = "rt-${local.name_prefix}-firewall-egress"
  resource_group_name           = azurerm_resource_group.connectivity.name
  location                      = azurerm_resource_group.connectivity.location
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

resource "azurerm_route" "default_to_firewall" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name                   = "default-to-azure-firewall"
  resource_group_name    = azurerm_resource_group.connectivity.name
  route_table_name       = azurerm_route_table.firewall_egress["main"].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub["main"].ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "firewall_egress" {
  for_each = local.firewall_route_association_subnet_ids

  subnet_id      = each.value
  route_table_id = azurerm_route_table.firewall_egress["main"].id
}
