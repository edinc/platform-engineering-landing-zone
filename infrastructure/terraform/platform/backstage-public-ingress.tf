resource "azurerm_public_ip" "backstage_public_ingress" {
  count = local.backstage_public_ingress_enabled ? 1 : 0

  name                = "pip-${local.name_prefix}-backstage-public"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = local.backstage_public_ingress_dns_label
  zones               = var.profile == "prod" && length(var.availability_zones) > 0 ? var.availability_zones : null
  tags                = local.tags

  lifecycle {
    ignore_changes = [
      ip_tags,
    ]
  }
}

resource "azurerm_role_assignment" "backstage_public_ingress_aks_network" {
  count = local.backstage_public_ingress_enabled ? 1 : 0

  scope                = azurerm_public_ip.backstage_public_ingress[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_network_security_rule" "backstage_public_ingress_lb" {
  #checkov:skip=CKV_AZURE_160: HTTP-01 ACME validation requires public port 80; Backstage traffic is restricted by the nginx ingress allowlist.
  for_each = local.backstage_public_ingress_enabled ? {
    aks-user = azurerm_network_security_group.platform["aks-user"].name
  } : {}

  name                        = "allow-backstage-public-lb"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["80", "443"]
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = each.value
}
