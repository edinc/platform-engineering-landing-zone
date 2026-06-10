output "resource_group_name" {
  value       = azurerm_resource_group.connectivity.name
  description = "Connectivity resource group name."
}

output "hub_virtual_network_id" {
  value       = azurerm_virtual_network.hub.id
  description = "Hub virtual network resource ID."
}

output "hub_subnet_ids" {
  value       = { for name, subnet in azurerm_subnet.hub : name => subnet.id }
  description = "Hub subnet IDs keyed by subnet name."
}

output "firewall_id" {
  value       = try(azurerm_firewall.hub["main"].id, null)
  description = "Azure Firewall ID for non-demo profiles, or null for demo."
}

output "firewall_private_ip_address" {
  value       = try(azurerm_firewall.hub["main"].ip_configuration[0].private_ip_address, null)
  description = "Azure Firewall private IP used as the default route next hop, or null for demo."
}

output "firewall_policy_id" {
  value       = try(azurerm_firewall_policy.egress["main"].id, null)
  description = "Azure Firewall Policy ID for non-demo profiles, or null for demo."
}

output "firewall_route_table_id" {
  value       = try(azurerm_route_table.firewall_egress["main"].id, null)
  description = "Route table that forces 0.0.0.0/0 to Azure Firewall for non-demo profiles."
}

output "nat_gateway_id" {
  value       = try(azurerm_nat_gateway.demo["main"].id, null)
  description = "Demo NAT Gateway ID, or null for non-demo profiles."
}

output "private_dns_zone_ids" {
  value       = { for name, zone in azurerm_private_dns_zone.this : name => zone.id }
  description = "Private DNS zone IDs keyed by zone name."
}

output "monitor_private_link_scope_id" {
  value       = try(azurerm_monitor_private_link_scope.ampls["main"].id, null)
  description = "Azure Monitor Private Link Scope ID, or null when disabled."
}

output "monitor_private_link_scope_private_endpoint_id" {
  value       = try(azurerm_private_endpoint.ampls["main"].id, null)
  description = "Private Endpoint ID for AMPLS, or null when AMPLS is disabled."
}

output "private_endpoint_ids" {
  value       = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
  description = "Private Endpoint IDs keyed by private_endpoints input key."
}

output "hub_to_spoke_peering_ids" {
  value       = { for key, peering in azurerm_virtual_network_peering.hub_to_spoke : key => peering.id }
  description = "Hub-to-spoke peering IDs keyed by spoke_virtual_network_ids key. Cross-subscription peerings require the vending/workload-owned reverse peering before the path is connected."
}

output "same_subscription_spoke_to_hub_peering_ids" {
  value       = { for key, peering in azurerm_virtual_network_peering.spoke_to_hub : key => peering.id }
  description = "Reverse spoke-to-hub peering IDs created only for spokes in the connectivity subscription."
}

output "backend_config_hint" {
  value = {
    container_name   = "connectivity"
    key              = "${var.profile}/connectivity.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
