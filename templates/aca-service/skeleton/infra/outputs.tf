output "container_app_id" {
  value       = azurerm_container_app.this.id
  description = "Azure Container App resource ID."
}

output "container_app_name" {
  value       = azurerm_container_app.this.name
  description = "Azure Container App name."
}

output "container_app_fqdn" {
  value       = try(azurerm_container_app.this.ingress[0].fqdn, null)
  description = "Public ACA FQDN when public ingress is enabled."
}

output "managed_identity_principal_id" {
  value       = azurerm_user_assigned_identity.workload.principal_id
  description = "Workload identity principal ID."
}
