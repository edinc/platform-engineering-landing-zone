output "resource_group_name" {
  value       = azurerm_resource_group.demo.name
  description = "Demo resource group name."
}

output "resource_group_id" {
  value       = azurerm_resource_group.demo.id
  description = "Demo resource group ID."
}

output "tags" {
  value       = local.tags
  description = "Mandatory tag set applied to demo resources."
}
