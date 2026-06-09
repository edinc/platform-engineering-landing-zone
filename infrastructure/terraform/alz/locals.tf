locals {
  # Regional resource names for the management subscription.
  management_rg_name        = "rg-pe-alz-mgmt-${var.location_short}"
  log_analytics_name        = "log-pe-alz-${var.location_short}"
  cost_storage_account_name = lower("stpealzcost${var.location_short}${var.name_suffix}")
  cost_export_container     = "cost-exports"

  # Parent of the top-level alz MG. Defaults to the Tenant Root Group, whose MG
  # ID equals the tenant ID. Overridable for brownfield nesting.
  root_parent_id = var.root_management_group_id != "" ? var.root_management_group_id : "/providers/Microsoft.Management/managementGroups/${var.tenant_id}"

  # ALZ management-group hierarchy (plan.md / stage-02 scope):
  #   Tenant Root -> alz -> { platform, landingzones, sandbox, decommissioned }
  #   platform     -> { management, connectivity, identity }
  #   landingzones -> { corp, online }
  # parent = null means the node hangs off root_parent_id.
  management_groups = {
    alz            = { display_name = "Azure Landing Zones", parent = null }
    platform       = { display_name = "Platform", parent = "alz" }
    landingzones   = { display_name = "Landing Zones", parent = "alz" }
    sandbox        = { display_name = "Sandbox", parent = "alz" }
    decommissioned = { display_name = "Decommissioned", parent = "alz" }
    management     = { display_name = "Management", parent = "platform" }
    connectivity   = { display_name = "Connectivity", parent = "platform" }
    identity       = { display_name = "Identity", parent = "platform" }
    corp           = { display_name = "Corp", parent = "landingzones" }
    online         = { display_name = "Online", parent = "landingzones" }
  }

  # Depth of each MG below root_parent_id (0 = directly under root). The
  # hierarchy is materialised as one resource per tier (see management-groups.tf)
  # because a single self-referencing for_each resource deadlocks terraform plan
  # with a Cycle error. try() keeps this resilient to a mistyped parent key; the
  # terraform_data.mg_guard precondition turns both an unknown parent and a node
  # nested deeper than tier 2 into hard plan-time failures.
  mg_depth = { for k, v in local.management_groups : k => (
    v.parent == null ? 0 :
    try(local.management_groups[v.parent].parent == null, false) ? 1 :
    try(local.management_groups[local.management_groups[v.parent].parent].parent == null, false) ? 2 : 3
  ) }

  mg_tier0 = { for k, v in local.management_groups : k => v if local.mg_depth[k] == 0 }
  mg_tier1 = { for k, v in local.management_groups : k => v if local.mg_depth[k] == 1 }
  mg_tier2 = { for k, v in local.management_groups : k => v if local.mg_depth[k] == 2 }

  # Optional subscription -> MG associations. Only entries with a non-empty
  # subscription ID are created, keeping the stack brownfield-safe.
  subscription_associations = {
    for mg, sub in {
      management   = var.associate_management_subscription ? var.management_subscription_id : ""
      connectivity = var.connectivity_subscription_id
      identity     = var.identity_subscription_id
      corp         = var.corp_subscription_id
    } : mg => sub if sub != ""
  }

  # Single tier-agnostic lookup of MG short name -> resource ID, merged across the
  # tier resources so call sites stay unaware of which tier a node lives in.
  mg_ids = merge(
    { for k, r in azurerm_management_group.root : k => r.id },
    { for k, r in azurerm_management_group.level1 : k => r.id },
    { for k, r in azurerm_management_group.level2 : k => r.id },
  )

  # Built-in Azure Policy / initiative GUIDs. Pinned and verified against the
  # canonical Azure/azure-policy repository (raw built-in definitions). Update
  # only with a re-verified GUID and a review.
  builtin = {
    # CIS Microsoft Azure Foundations Benchmark v2.0.0 (policy SET definition).
    cis_foundations_v2 = "06f19060-9e68-4070-92ca-f15cc126059e"
    # AKS Policy (Gatekeeper) add-on DeployIfNotExists - INTENTIONALLY EXCLUDED
    # from aks-baseline (acceptance criterion 8, ADR-0036). Asserted absent.
    aks_policy_addon_gatekeeper = "a8eff44f-8c92-45c3-a3fb-9880802d67a7"
  }

  # Mandatory tag taxonomy (plan.md section 10). The alz stack manages shared
  # platform infrastructure, so env = platform / managedBy = terraform.
  tags = merge(
    {
      env                = "platform"
      owner              = "platform-engineering"
      costCenter         = var.cost_center
      product            = "landing-zone"
      dataClassification = "internal"
      confidentiality    = "moderate"
      managedBy          = "terraform"
      repo               = "${var.github_owner}/${var.github_repo}"
    },
    var.extra_tags,
  )

  # Defender for Cloud plans keyed by the EXACT azurerm resource_type strings.
  # Plans whose Standard tier requires a subplan carry it here; defender.tf only
  # emits the subplan when the tier is Standard (a subplan is invalid with Free).
  # Servers uses P2 (full features), APIs uses P1 (entry plan), and Storage uses
  # the modern DefenderForStorageV2 plan. The remaining plans expose a single
  # Standard offering and take no subplan. azurerm documents subplan values as
  # MSFT-representative-supplied, so operators should confirm them against their
  # tenant before enabling the Standard (nonprod/prod) profiles.
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
