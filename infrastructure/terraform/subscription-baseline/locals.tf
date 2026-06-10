locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"
  normalized_log_analytics_workspace_subscription_ids = [
    for id in var.approved_log_analytics_workspace_subscription_ids : lower(id)
  ]
  normalized_cost_export_storage_subscription_ids = [
    for id in var.approved_cost_export_storage_subscription_ids : lower(id)
  ]
  log_analytics_workspace_subscription_id = try(lower(regex("^/subscriptions/([^/]+)/", var.log_analytics_workspace_id)[0]), "")
  cost_export_storage_subscription_id     = try(lower(regex("^/subscriptions/([^/]+)/", var.cost_export_storage_container_id)[0]), "")

  activity_log_categories = [
    "Administrative",
    "Security",
    "ServiceHealth",
    "Alert",
    "Recommendation",
    "Policy",
    "Autoscale",
    "ResourceHealth",
  ]

  # Defender for Cloud plans keyed by the EXACT azurerm resource_type strings.
  # Plans whose Standard tier requires a subplan carry it here; defender.tf only
  # emits the subplan when the tier is Standard (a subplan is invalid with Free).
  defender_plans = {
    VirtualMachines               = { tier = var.defender_tiers.virtual_machines, subplan = "P2" }
    Containers                    = { tier = var.defender_tiers.containers, subplan = null }
    KeyVaults                     = { tier = var.defender_tiers.key_vaults, subplan = null }
    StorageAccounts               = { tier = var.defender_tiers.storage_accounts, subplan = "DefenderForStorageV2" }
    SqlServers                    = { tier = var.defender_tiers.sql_servers, subplan = null }
    OpenSourceRelationalDatabases = { tier = var.defender_tiers.open_source_dbs, subplan = null }
    Arm                           = { tier = var.defender_tiers.resource_manager, subplan = null }
    Api                           = { tier = var.defender_tiers.apis, subplan = "P1" }
  }
}
