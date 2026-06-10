resource "azurerm_public_ip" "firewall" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name                = "pip-${local.name_prefix}-fw"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = length(var.availability_zones) > 0 ? var.availability_zones : null
  tags                = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_public_ip" "firewall_management" {
  for_each = local.firewall_enabled && var.firewall_forced_tunneling_enabled ? { main = true } : {}

  name                = "pip-${local.name_prefix}-fw-mgmt"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = length(var.availability_zones) > 0 ? var.availability_zones : null
  tags                = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_firewall_policy" "egress" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name                     = "afwp-${local.name_prefix}-egress"
  resource_group_name      = azurerm_resource_group.connectivity.name
  location                 = azurerm_resource_group.connectivity.location
  sku                      = "Premium"
  base_policy_id           = var.firewall_base_policy_id != "" ? var.firewall_base_policy_id : null
  threat_intelligence_mode = "Deny"
  private_ip_ranges        = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  tags                     = local.tags

  dns {
    proxy_enabled = true
  }

  intrusion_detection {
    mode = "Deny"
  }

  dynamic "insights" {
    for_each = var.log_analytics_workspace_id == "" ? [] : [var.log_analytics_workspace_id]

    content {
      enabled                            = true
      default_log_analytics_workspace_id = insights.value
      retention_in_days                  = 30
    }
  }
}

resource "azurerm_firewall" "hub" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name                = "afw-${local.name_prefix}-hub"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.egress["main"].id
  threat_intel_mode   = "Deny"
  zones               = length(var.availability_zones) > 0 ? var.availability_zones : null
  tags                = local.tags

  ip_configuration {
    name                 = "public"
    subnet_id            = azurerm_subnet.hub["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall["main"].id
  }

  dynamic "management_ip_configuration" {
    for_each = var.firewall_forced_tunneling_enabled ? [1] : []

    content {
      name                 = "management"
      subnet_id            = azurerm_subnet.hub["AzureFirewallManagementSubnet"].id
      public_ip_address_id = azurerm_public_ip.firewall_management["main"].id
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "egress_allowlist" {
  for_each = local.firewall_enabled ? { main = true } : {}

  name               = "rcg-platform-egress-allowlist"
  firewall_policy_id = azurerm_firewall_policy.egress["main"].id
  priority           = 500

  dynamic "application_rule_collection" {
    for_each = local.firewall_allowlist.application_rule_collections

    content {
      name     = application_rule_collection.value.name
      priority = application_rule_collection.value.priority
      action   = application_rule_collection.value.action

      dynamic "rule" {
        for_each = application_rule_collection.value.rules

        content {
          name              = rule.value.name
          source_addresses  = local.firewall_allowlist_source_addresses
          destination_fqdns = rule.value.destination_fqdns

          dynamic "protocols" {
            for_each = rule.value.protocols

            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }

  dynamic "network_rule_collection" {
    for_each = try(local.firewall_allowlist.network_rule_collections, [])

    content {
      name     = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action   = network_rule_collection.value.action

      dynamic "rule" {
        for_each = network_rule_collection.value.rules

        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = local.firewall_allowlist_source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }
}

resource "azurerm_public_ip" "demo_nat" {
  for_each = local.nat_enabled ? { main = true } : {}

  name                = "pip-${local.name_prefix}-nat"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = length(local.nat_gateway_zones) > 0 ? local.nat_gateway_zones : null
  tags                = local.tags
}

resource "azurerm_nat_gateway" "demo" {
  for_each = local.nat_enabled ? { main = true } : {}

  name                    = "nat-${local.name_prefix}"
  resource_group_name     = azurerm_resource_group.connectivity.name
  location                = azurerm_resource_group.connectivity.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = length(local.nat_gateway_zones) > 0 ? local.nat_gateway_zones : null
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "demo" {
  for_each = local.nat_enabled ? { main = true } : {}

  nat_gateway_id       = azurerm_nat_gateway.demo["main"].id
  public_ip_address_id = azurerm_public_ip.demo_nat["main"].id
}

resource "azurerm_subnet_nat_gateway_association" "demo_shared_services" {
  for_each = local.nat_enabled ? { shared_services = azurerm_subnet.hub["shared-services"].id } : {}

  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.demo["main"].id
}
