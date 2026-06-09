# Policy assignments. Effects honour Stage 02 acceptance criteria 2 and 3:
# - tag-baseline is the only Deny (criterion 3);
# - CIS is evaluation-only by default (cis_enforce = false) so it does not add
#   broad denies during the grace period;
# - private-link and aks-baseline are Audit.

# CIS Microsoft Azure Foundations Benchmark v2 at the alz MG. A SystemAssigned
# identity + location are attached so the assignment can be flipped to enforced
# (cis_enforce = true) later without recreation; remediation roles for the
# identity are granted out of band when enforcement is enabled (ADR-0011).
resource "azurerm_management_group_policy_assignment" "cis" {
  name                 = "cis-foundations-v2"
  display_name         = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
  description          = "CIS v2 compliance baseline (ADR-0011). Evaluation-only until cis_enforce = true."
  management_group_id  = local.mg_ids["alz"]
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/${local.builtin.cis_foundations_v2}"
  enforce              = var.cis_enforce
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

# Mandatory tag baseline (Deny) at the alz MG. Enforced by default to satisfy
# acceptance criterion 3. Built-in members are fixed-Deny, so enforcement is
# controlled by enforce (Default vs DoNotEnforce), not by an effect parameter.
resource "azurerm_management_group_policy_assignment" "tag_baseline" {
  name                 = "pe-tag-baseline"
  display_name         = "Platform Engineering - mandatory tag baseline (Deny)"
  description          = "Denies resources and resource groups missing mandatory platform tags (acceptance criterion 3)."
  management_group_id  = local.mg_ids["alz"]
  policy_definition_id = azurerm_policy_set_definition.custom["tag-baseline"].id
  enforce              = var.tag_baseline_enforce
}

# Private Link / no public network access (Audit) at the alz MG.
resource "azurerm_management_group_policy_assignment" "private_link" {
  name                 = "pe-private-link"
  display_name         = "Platform Engineering - Private Link required"
  management_group_id  = local.mg_ids["alz"]
  policy_definition_id = azurerm_policy_set_definition.custom["private-link-required"].id

  parameters = jsonencode({
    effect = { value = var.private_link_effect }
  })
}

# AKS security baseline (Audit) at the landingzones MG, where workload clusters
# live. Deliberately excludes the Gatekeeper add-on (criterion 8).
resource "azurerm_management_group_policy_assignment" "aks_baseline" {
  name                 = "pe-aks-baseline"
  display_name         = "Platform Engineering - AKS security baseline"
  management_group_id  = local.mg_ids["landingzones"]
  policy_definition_id = azurerm_policy_set_definition.custom["aks-baseline"].id

  parameters = jsonencode({
    effect = { value = var.aks_effect }
  })
}

# Optional platform-wide diagnostic-settings DeployIfNotExists assignment routing
# logs to the central workspace. Disabled until an operator supplies a concrete
# DINE policy/initiative ID, because the parameter schema is policy-specific.
resource "azurerm_management_group_policy_assignment" "diagnostics" {
  count = var.diagnostics_policy_definition_id != "" ? 1 : 0

  name                 = "pe-diag-to-la"
  display_name         = "Platform Engineering - route diagnostics to central LA"
  management_group_id  = local.mg_ids["platform"]
  policy_definition_id = var.diagnostics_policy_definition_id
  location             = var.location

  identity {
    type = "SystemAssigned"
  }

  parameters = length(var.diagnostics_policy_parameters) > 0 ? jsonencode(var.diagnostics_policy_parameters) : null
}

# Remediation roles for the diagnostics DINE identity at the platform MG.
resource "azurerm_role_assignment" "diagnostics_monitoring" {
  count = var.diagnostics_policy_definition_id != "" ? 1 : 0

  scope                = local.mg_ids["platform"]
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_management_group_policy_assignment.diagnostics[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "diagnostics_log_analytics" {
  count = var.diagnostics_policy_definition_id != "" ? 1 : 0

  scope                = local.mg_ids["platform"]
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_management_group_policy_assignment.diagnostics[0].identity[0].principal_id
}

# Surface (without failing the run) when platform-wide diagnostics DINE is not
# configured, so central logging cannot be silently unmet. Per-resource
# diagnostic wiring is also done by each stage's modules against the workspace
# exported as log_analytics_workspace_id.
check "diagnostics_policy_configured" {
  assert {
    condition     = var.diagnostics_policy_definition_id != ""
    error_message = "Platform-wide diagnostics DINE is NOT assigned: set diagnostics_policy_definition_id (and diagnostics_policy_parameters) to route resource logs to the central Log Analytics workspace."
  }
}
