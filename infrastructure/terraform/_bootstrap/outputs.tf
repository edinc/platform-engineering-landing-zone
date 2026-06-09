output "resource_group_name" {
  value       = azurerm_resource_group.tfstate.name
  description = "Resource group holding Terraform remote state and bootstrap resources."
}

output "state_storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "Storage account name for the AzureRM backend (use_azuread_auth = true)."
}

output "state_containers" {
  value       = sort([for c in azurerm_storage_container.stage : c.name])
  description = "Provisioned per-stage state containers."
}

output "key_vault_name" {
  value       = azurerm_key_vault.bootstrap.name
  description = "Seed Key Vault name (bootstrap secrets and state CMK)."
}

output "key_vault_id" {
  value       = azurerm_key_vault.bootstrap.id
  description = "Seed Key Vault resource ID."
}

output "state_cmk_key_id" {
  value       = azurerm_key_vault_key.state_cmk.id
  description = "Customer-managed key versionless ID protecting Terraform state."
}

output "cmk_identity_principal_id" {
  value       = azurerm_user_assigned_identity.cmk.principal_id
  description = "Principal ID of the user-assigned identity used for state CMK access."
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.bootstrap.id
  description = "Bootstrap Log Analytics workspace ID for break-glass alerting and Entra diagnostic wiring."
}

output "backend_config_hint" {
  value = {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = "bootstrap"
    key                  = "bootstrap.tfstate"
    use_azuread_auth     = true
  }
  description = "Backend settings for this stack's own state (mirror into backend.hcl)."
}
