locals {
  name_prefix = "pe-${var.profile}-${var.location_short}"
  resource_group_name = (
    var.resource_group_name != "" ? var.resource_group_name : "rg-pe-${var.profile}-connectivity-${var.location_short}"
  )

  firewall_enabled = var.profile != "demo"
  nat_enabled      = var.profile == "demo"
  nat_gateway_zones = (
    local.nat_enabled && length(var.availability_zones) > 0 ? [var.availability_zones[0]] : []
  )

  hub_subnets = merge(
    var.subnet_address_prefixes,
    var.firewall_forced_tunneling_enabled ? {
      AzureFirewallManagementSubnet = var.firewall_management_subnet_address_prefix
    } : {},
  )

  base_private_dns_zone_names = [
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.${var.location}.azmk8s.io",
    "privatelink.servicebus.windows.net",
  ]

  monitor_private_dns_zone_names = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net",
  ]

  private_dns_zone_names = toset(concat(
    local.base_private_dns_zone_names,
    var.enable_monitor_private_link_scope ? local.monitor_private_dns_zone_names : [],
    var.additional_private_dns_zone_names,
  ))

  dns_link_vnets = merge(
    { hub = azurerm_virtual_network.hub.id },
    var.spoke_virtual_network_ids,
  )

  spoke_virtual_networks = {
    for key, id in var.spoke_virtual_network_ids : key => {
      id                  = id
      subscription_id     = lower(regex("^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.Network/virtualNetworks/([^/]+)$", id)[0])
      resource_group_name = regex("^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.Network/virtualNetworks/([^/]+)$", id)[1]
      name                = regex("^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.Network/virtualNetworks/([^/]+)$", id)[2]
    }
  }

  same_subscription_spoke_virtual_networks = {
    for key, spoke in local.spoke_virtual_networks : key => spoke
    if spoke.subscription_id == lower(var.subscription_id)
  }

  private_dns_vnet_links = merge([
    for zone_name in local.private_dns_zone_names : {
      for vnet_key, vnet_id in local.dns_link_vnets : "${zone_name}|${vnet_key}" => {
        zone_name = zone_name
        vnet_key  = vnet_key
        vnet_id   = vnet_id
      }
    }
  ]...)

  firewall_route_association_subnet_ids = local.firewall_enabled ? merge(
    { shared_services = azurerm_subnet.hub["shared-services"].id },
    var.workload_subnet_ids,
  ) : {}

  firewall_allowlist_source_addresses = (
    distinct(concat([var.subnet_address_prefixes["shared-services"]], var.firewall_allowlist_source_addresses))
  )

  firewall_allowlist = jsondecode(file("${path.module}/../../../policies/azure/firewall/allowlist.json"))

  tags = merge(
    {
      env                = var.profile
      owner              = var.owner
      costCenter         = var.cost_center
      product            = "landing-zone"
      dataClassification = "internal"
      confidentiality    = var.profile == "prod" ? "high" : "low"
      managedBy          = "terraform"
      repo               = "${var.github_owner}/${var.github_repo}"
    },
    var.extra_tags,
  )
}
