# Bootstrap-scoped monitoring for break-glass account activation (acceptance
# criterion 3). This is a minimal Phase 1 workspace; Stage 02 introduces the
# central Log Analytics workspace and Defender for Cloud.
#
# The Entra ID diagnostic setting that routes SigninLogs/AuditLogs into this
# workspace is a tenant-level operation that the bootstrap deploy identity
# intentionally cannot perform; it is wired by a Global Admin as a documented
# post-apply step (docs/runbooks/bootstrap.md, ADR-0024).
resource "azurerm_log_analytics_workspace" "bootstrap" {
  name                = local.log_analytics_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = local.tags
}

resource "azurerm_monitor_action_group" "break_glass" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.tfstate.name
  short_name          = "pe-bg"

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = "breakglass-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = local.tags
}

# Alerts when any break-glass account signs in. Disabled until break-glass UPNs
# are provided, because the KQL requires concrete principals.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "break_glass_signin" {
  count = length(var.break_glass_upns) > 0 ? 1 : 0

  name                = "alert-pe-breakglass-signin-${var.location_short}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  description         = "Break-glass account sign-in detected. Confirm the activation was authorized (ADR-0024)."
  severity            = 1
  enabled             = true

  # A fresh Log Analytics workspace has no SigninLogs table until Entra
  # diagnostic settings are wired (post-apply, Global Admin) and a sign-in
  # actually flows, so create-time KQL validation would fail and block the apply
  # (acceptance criterion 3). Skip the static validation; the rule still
  # evaluates the query at runtime once the table exists.
  skip_query_validation = true

  scopes                  = [azurerm_log_analytics_workspace.bootstrap.id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT5M"
  auto_mitigation_enabled = false

  criteria {
    query = <<-KQL
      SigninLogs
      | where UserPrincipalName in~ (${join(", ", [for upn in var.break_glass_upns : "\"${upn}\""])})
      | project TimeGenerated, UserPrincipalName, IPAddress, ResultType, AppDisplayName
    KQL

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.break_glass.id]
  }

  tags = local.tags
}

# Surface (without failing the run) when break-glass detection is inert, so
# acceptance criterion 3 cannot be silently unmet. The SigninLogs route itself is
# a tenant-level Global Admin step tracked in the runbook and ADR-0024.
check "break_glass_detection" {
  assert {
    condition     = length(var.break_glass_upns) > 0
    error_message = "Break-glass sign-in alert is NOT created: set break_glass_upns once the cloud-only break-glass accounts exist (ADR-0024, acceptance criterion 3)."
  }

  assert {
    condition     = length(var.alert_email_receivers) > 0
    error_message = "Break-glass action group has no receivers: set alert_email_receivers so activation alerts notify someone (ADR-0024)."
  }
}
