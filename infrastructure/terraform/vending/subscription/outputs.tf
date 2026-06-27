output "subscription_id" {
  value       = module.lz_vending.subscription_id
  description = "Vended workload subscription ID."
}

output "subscription_resource_id" {
  value       = module.lz_vending.subscription_resource_id
  description = "ARM resource ID for the vended workload subscription."
}

output "virtual_network_resource_ids" {
  value       = module.lz_vending.virtual_network_resource_ids
  description = "Vended workload spoke VNet IDs keyed by lz-vending VNet key."
}

output "virtual_network_resource_group_ids" {
  value       = module.lz_vending.virtual_network_resource_group_ids
  description = "Vended workload spoke resource group IDs keyed by lz-vending VNet key."
}

output "management_group_subscription_association_id" {
  value       = module.lz_vending.management_group_subscription_association_id
  description = "Management group association ID for the vended workload subscription."
}

output "subscription_baseline_handoff" {
  value = {
    container_name        = "subscription-baseline"
    key                   = "subscriptions/${module.lz_vending.subscription_id}/subscription-baseline.tfstate"
    use_azuread_auth      = true
    target_subscription   = module.lz_vending.subscription_id
    management_group_id   = var.management_group_id
    subscription_alias    = var.subscription_alias_name
    subscription_workload = var.subscription_workload
  }
  description = "Backend and target hints for post-vending subscription baseline."
}

output "backend_config_hint" {
  value = {
    container_name   = "vending"
    key              = "subscriptions/${var.subscription_alias_name}/terraform.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
