resource "terraform_data" "input_guard" {
  input = {
    profile                           = var.profile
    firewall_forced_tunneling_enabled = var.firewall_forced_tunneling_enabled
    private_endpoint_count            = length(var.private_endpoints)
    monitor_linked_resource_ids       = var.monitor_linked_resource_ids
  }

  lifecycle {
    precondition {
      condition     = var.profile == "demo" || contains(keys(local.hub_subnets), "AzureFirewallSubnet")
      error_message = "non-demo profiles require AzureFirewallSubnet in subnet_address_prefixes."
    }

    precondition {
      condition     = !var.firewall_forced_tunneling_enabled || contains(keys(local.hub_subnets), "AzureFirewallManagementSubnet")
      error_message = "firewall_forced_tunneling_enabled requires AzureFirewallManagementSubnet."
    }

    precondition {
      condition = alltrue([
        for endpoint in values(var.private_endpoints) :
        length(endpoint.subresource_names) > 0 && length(endpoint.private_dns_zone_names) > 0
      ])
      error_message = "Each private_endpoints entry must define at least one subresource and one Private DNS zone."
    }

    precondition {
      condition     = var.enable_monitor_private_link_scope || length(var.monitor_linked_resource_ids) == 0
      error_message = "monitor_linked_resource_ids can only be set when enable_monitor_private_link_scope is true."
    }

    precondition {
      condition     = !var.enable_monitor_private_link_scope || length(var.monitor_linked_resource_ids) > 0
      error_message = "enable_monitor_private_link_scope requires at least one monitor_linked_resource_ids entry to avoid empty AMPLS PrivateOnly DNS interception."
    }

    precondition {
      condition = alltrue([
        for subnet_id in values(var.workload_subnet_ids) :
        lower(regex("^/subscriptions/([^/]+)/", subnet_id)[0]) == lower(var.subscription_id)
      ])
      error_message = "workload_subnet_ids must be in the connectivity subscription. Cross-subscription UDR association is handled by Stage 05 vending/workload stacks."
    }

    precondition {
      condition     = var.profile != "demo" || length(var.workload_subnet_ids) == 0
      error_message = "workload_subnet_ids is not supported for the demo profile; associate later demo workload subnets with nat_gateway_id instead."
    }

    precondition {
      condition     = length(var.workload_subnet_ids) == 0 || length(var.firewall_allowlist_source_addresses) > 0
      error_message = "workload_subnet_ids requires explicit firewall_allowlist_source_addresses so routed workload subnets are not silently default-denied by source matching."
    }

    precondition {
      condition = (
        length(var.workload_subnet_ids) == 0 ||
        length(setsubtract(toset(keys(var.workload_subnet_ids)), toset(keys(var.workload_subnet_source_prefixes)))) == 0
      )
      error_message = "workload_subnet_source_prefixes must include every workload_subnet_ids key."
    }

    precondition {
      condition = alltrue([
        for cidr in values(var.workload_subnet_source_prefixes) :
        contains(local.firewall_allowlist_source_addresses, cidr)
      ])
      error_message = "Every workload_subnet_source_prefixes CIDR must also be present in firewall_allowlist_source_addresses."
    }

    precondition {
      condition = alltrue([
        for cidr in local.firewall_allowlist_source_addresses :
        can(cidrhost(cidr, 0)) &&
        can(tonumber(split("/", cidr)[1])) &&
        tonumber(split("/", cidr)[1]) >= 20 &&
        tonumber(split("/", cidr)[1]) <= 32 &&
        cidr != "0.0.0.0/0" &&
        !contains(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], cidr)
      ])
      error_message = "Computed firewall allowlist source addresses must be valid, specific IPv4 CIDRs (/20 or narrower), not broad internet/RFC1918 supernets."
    }

    precondition {
      condition = alltrue(flatten([
        for endpoint in values(var.private_endpoints) : [
          for zone_name in endpoint.private_dns_zone_names : contains(local.private_dns_zone_names, zone_name)
        ]
      ]))
      error_message = "Every private_endpoints private_dns_zone_names entry must be part of the base zones, AMPLS zones, or additional_private_dns_zone_names."
    }
  }
}

resource "azurerm_resource_group" "connectivity" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${local.name_prefix}-hub"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = var.hub_vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "hub" {
  #checkov:skip=CKV2_AZURE_31:This for_each includes GatewaySubnet and AzureFirewallSubnet, where uniform NSG association is not appropriate; eligible shared/private subnets have NSGs associated below.
  for_each = local.hub_subnets

  name                              = each.key
  resource_group_name               = azurerm_resource_group.connectivity.name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [each.value]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.key == "private-endpoints" ? "Enabled" : null
}

resource "azurerm_network_security_group" "hub" {
  for_each = {
    private-endpoints = "private-endpoints"
    shared-services   = "shared-services"
  }

  name                = "nsg-${local.name_prefix}-${each.value}"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "hub" {
  for_each = azurerm_network_security_group.hub

  subnet_id                 = azurerm_subnet.hub[each.key].id
  network_security_group_id = each.value.id
}
