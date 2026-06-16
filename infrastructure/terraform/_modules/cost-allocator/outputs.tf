output "function_app_id" {
  value       = azurerm_linux_function_app.this.id
  description = "Cost allocator Function App resource ID."
}

output "function_app_name" {
  value       = azurerm_linux_function_app.this.name
  description = "Cost allocator Function App name."
}

output "function_app_principal_id" {
  value       = azurerm_linux_function_app.this.identity[0].principal_id
  description = "System-assigned managed identity principal ID used for Cost Management export reads and showback writes."
}

output "storage_account_id" {
  value       = azurerm_storage_account.this.id
  description = "Storage account ID used for Function host state and showback output."
}

output "showback_container_id" {
  value       = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.showback.name}"
  description = "Showback output container resource ID."
}

output "showback_container_url" {
  value       = "https://${azurerm_storage_account.this.name}.blob.core.windows.net/${azurerm_storage_container.showback.name}"
  description = "Showback output container URL used by Backstage Cost Insights."
}
