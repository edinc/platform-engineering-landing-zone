# Optional subscription Activity Log diagnostics. The central workspace is an
# existing ALZ shared service passed in by resource ID.
resource "azurerm_monitor_diagnostic_setting" "subscription_activity" {
  count = var.enable_activity_log_diagnostics ? 1 : 0

  name                       = "diag-subscription-activity-to-la"
  target_resource_id         = local.subscription_scope
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = local.activity_log_categories
    content {
      category = enabled_log.value
    }
  }
}
