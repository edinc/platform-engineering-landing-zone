resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = local.spoke_virtual_networks

  name                      = "peer-hub-to-${substr(sha1(each.value.id), 0, 8)}"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = each.value.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = local.same_subscription_spoke_virtual_networks

  name                      = "peer-${substr(sha1(each.value.id), 0, 8)}-to-hub"
  resource_group_name       = each.value.resource_group_name
  virtual_network_name      = each.value.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
