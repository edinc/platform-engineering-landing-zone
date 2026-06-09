output "management_group_ids" {
  value       = local.mg_ids
  description = "Map of management-group short name to resource ID."
}

output "root_parent_id" {
  value       = local.root_parent_id
  description = "Parent management group ID under which the alz hierarchy is created."
}

output "initiative_ids" {
  value       = { for key, set in azurerm_policy_set_definition.custom : key => set.id }
  description = "Map of custom initiative short name to policy set definition ID."
}

output "policy_assignment_ids" {
  value = {
    cis          = azurerm_management_group_policy_assignment.cis.id
    tag_baseline = azurerm_management_group_policy_assignment.tag_baseline.id
    private_link = azurerm_management_group_policy_assignment.private_link.id
    aks_baseline = azurerm_management_group_policy_assignment.aks_baseline.id
  }
  description = "Map of policy assignment short name to assignment ID."
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.central.id
  description = "Central Log Analytics workspace ID. Use as the diagnostics destination (diagnostics_policy_parameters) and for per-stage diagnostic settings."
}

output "cost_export_storage_account_name" {
  value       = azurerm_storage_account.cost.name
  description = "ADLS Gen2 account receiving Cost Management exports."
}

output "defender_plan_tiers" {
  value       = { for k, p in azurerm_security_center_subscription_pricing.this : k => p.tier }
  description = "Effective Defender for Cloud plan tier per resource type on the management subscription."
}

output "backend_config_hint" {
  value = {
    container_name   = "alz"
    key              = "alz.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state (mirror into backend.hcl; resource_group_name and storage_account_name come from the _bootstrap outputs)."
}
