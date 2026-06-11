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
  # Plans whose Standard tier requires a default subplan carry it here; brownfield
  # subscriptions can override/preserve tenant-specific subplans and extensions
  # through defender_plan_subplans / defender_plan_extensions.
  defender_plans = {
    VirtualMachines = {
      tier       = var.defender_tiers.virtual_machines
      subplan    = try(var.defender_plan_subplans.VirtualMachines, "P2")
      extensions = try(var.defender_plan_extensions.VirtualMachines, [])
    }
    Containers = {
      tier       = var.defender_tiers.containers
      subplan    = try(var.defender_plan_subplans.Containers, null)
      extensions = try(var.defender_plan_extensions.Containers, [])
    }
    KeyVaults = {
      tier       = var.defender_tiers.key_vaults
      subplan    = try(var.defender_plan_subplans.KeyVaults, null)
      extensions = try(var.defender_plan_extensions.KeyVaults, [])
    }
    StorageAccounts = {
      tier       = var.defender_tiers.storage_accounts
      subplan    = try(var.defender_plan_subplans.StorageAccounts, "DefenderForStorageV2")
      extensions = try(var.defender_plan_extensions.StorageAccounts, [])
    }
    SqlServers = {
      tier       = var.defender_tiers.sql_servers
      subplan    = try(var.defender_plan_subplans.SqlServers, null)
      extensions = try(var.defender_plan_extensions.SqlServers, [])
    }
    OpenSourceRelationalDatabases = {
      tier       = var.defender_tiers.open_source_dbs
      subplan    = try(var.defender_plan_subplans.OpenSourceRelationalDatabases, null)
      extensions = try(var.defender_plan_extensions.OpenSourceRelationalDatabases, [])
    }
    Arm = {
      tier       = var.defender_tiers.resource_manager
      subplan    = try(var.defender_plan_subplans.Arm, null)
      extensions = try(var.defender_plan_extensions.Arm, [])
    }
    Api = {
      tier       = var.defender_tiers.apis
      subplan    = try(var.defender_plan_subplans.Api, "P1")
      extensions = try(var.defender_plan_extensions.Api, [])
    }
  }
}
