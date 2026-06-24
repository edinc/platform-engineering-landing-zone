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
}

resource "azurerm_role_assignment" "backstage_public_ingress_aks_network" {
  count = local.backstage_public_ingress_enabled ? 1 : 0

  scope                = azurerm_public_ip.backstage_public_ingress[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
  principal_type       = "ServicePrincipal"
}
