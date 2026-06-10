output "subscription_id" {
  value       = var.subscription_id
  description = "Target subscription ID for this baseline instance."
}

output "subscription_scope" {
  value       = local.subscription_scope
  description = "ARM scope for the target subscription."
}

output "activity_log_diagnostic_setting_id" {
  value       = try(azurerm_monitor_diagnostic_setting.subscription_activity[0].id, null)
  description = "Subscription Activity Log diagnostic setting ID, or null when diagnostics are disabled."
}

output "defender_plan_tiers" {
  value       = { for k, p in azurerm_security_center_subscription_pricing.this : k => p.tier }
  description = "Effective Defender for Cloud plan tier per resource type on the target subscription."
}

output "budget_id" {
  value       = try(azurerm_consumption_budget_subscription.this[0].id, null)
  description = "Subscription budget ID, or null when monthly_budget_amount is not set."
}

output "cost_export_id" {
  value       = try(azurerm_subscription_cost_management_export.this[0].id, null)
  description = "Cost Management export ID, or null when cost_export_storage_container_id is empty."
}

output "backend_config_hint" {
  value = {
    container_name   = "subscription-baseline"
    key              = "subscriptions/${var.subscription_id}/subscription-baseline.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state (mirror into backend.hcl; resource_group_name and storage_account_name come from the _bootstrap outputs)."
}
