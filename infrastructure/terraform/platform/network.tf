resource "azurerm_virtual_network" "platform" {
  name                = "vnet-${local.name_prefix}-platform"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = var.platform_vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "platform" {
  #checkov:skip=CKV2_AZURE_31:NSGs are associated through azurerm_subnet_network_security_group_association.platform; Checkov cannot trace the matching for_each map.
  for_each = var.subnet_address_prefixes

  name                              = each.key
  resource_group_name               = azurerm_resource_group.platform.name
  virtual_network_name              = azurerm_virtual_network.platform.name
  address_prefixes                  = [each.value]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.key == "private-endpoints" ? "Enabled" : null

  dynamic "delegation" {
    for_each = contains(keys(local.subnet_delegations), each.key) ? [local.subnet_delegations[each.key]] : []

    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "platform" {
  for_each = {
    aks-system        = "aks-system"
    aks-user          = "aks-user"
    private-endpoints = "private-endpoints"
    aca-infra         = "aca-infra"
    shared-ingress    = "shared-ingress"
  }

  name                = "nsg-${local.name_prefix}-${each.value}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "platform" {
  for_each = azurerm_network_security_group.platform

  subnet_id                 = azurerm_subnet.platform[each.key].id
  network_security_group_id = each.value.id
}

resource "azurerm_route_table" "egress" {
  count = local.route_table_enabled ? 1 : 0

  name                          = "rt-${local.name_prefix}-platform-egress"
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  bgp_route_propagation_enabled = false
  tags                          = local.tags
}

resource "azurerm_route" "default_to_firewall" {
  count = local.route_table_enabled ? 1 : 0

  name                   = "default-to-stage03-firewall"
  resource_group_name    = azurerm_resource_group.platform.name
  route_table_name       = azurerm_route_table.egress[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip_address
}

resource "azurerm_subnet_route_table_association" "egress" {
  for_each = local.route_table_enabled ? toset(local.route_table_subnet_keys) : toset([])

  subnet_id      = azurerm_subnet.platform[each.value].id
  route_table_id = azurerm_route_table.egress[0].id

  depends_on = [azurerm_route.default_to_firewall]
}

resource "azurerm_private_dns_zone_virtual_network_link" "platform" {
  provider = azurerm.dns
  for_each = local.private_dns_zone_links

  name                  = "lnk-platform-${substr(sha1(azurerm_virtual_network.platform.id), 0, 8)}"
  resource_group_name   = each.value.resource_group_name
  private_dns_zone_name = each.value.zone_name
  virtual_network_id    = azurerm_virtual_network.platform.id
  registration_enabled  = false
  tags                  = local.tags
}
