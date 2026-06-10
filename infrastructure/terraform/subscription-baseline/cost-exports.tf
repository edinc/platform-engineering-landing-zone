# Optional daily actual-cost export for the target subscription. The destination
# container is supplied by the existing ALZ/platform foundation; this stack does
# not create or firewall storage accounts.
resource "azurerm_subscription_cost_management_export" "this" {
  count = var.cost_export_storage_container_id == "" ? 0 : 1

  name                         = "export-pe-subscription-daily"
  subscription_id              = local.subscription_scope
  recurrence_type              = "Daily"
  recurrence_period_start_date = var.cost_export_recurrence_from
  recurrence_period_end_date   = var.cost_export_recurrence_to

  export_data_storage_location {
    container_id     = var.cost_export_storage_container_id
    root_folder_path = var.cost_export_root_folder
  }

  export_data_options {
    type       = "ActualCost"
    time_frame = "MonthToDate"
  }
}
