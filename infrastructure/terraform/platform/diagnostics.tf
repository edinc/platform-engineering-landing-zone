data "azurerm_monitor_diagnostic_categories" "platform" {
  for_each = local.diagnostic_targets

  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "platform" {
  for_each = local.diagnostic_targets

  name                       = "diag-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.platform[each.key].log_category_types)

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.platform[each.key].metrics)

    content {
      category = enabled_metric.value
    }
  }
}
