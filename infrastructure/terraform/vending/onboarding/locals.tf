locals {
  subscription_baseline_tfvars = {
    tenant_id                                         = var.tenant_id
    subscription_id                                   = var.subscription_id
    enable_activity_log_diagnostics                   = var.log_analytics_workspace_id != ""
    log_analytics_workspace_id                        = var.log_analytics_workspace_id
    approved_log_analytics_workspace_subscription_ids = var.log_analytics_workspace_id == "" ? [] : [regex("^/subscriptions/([^/]+)/", var.log_analytics_workspace_id)[0]]
    defender_tiers                                    = var.defender_tiers
    monthly_budget_amount                             = var.monthly_budget_amount
    budget_start_date                                 = var.budget_start_date
    budget_contact_emails                             = var.budget_contact_emails
    cost_export_storage_container_id                  = ""
    cost_export_recurrence_from                       = ""
    cost_export_recurrence_to                         = ""
    approved_cost_export_storage_subscription_ids     = []
  }

  backend_config_hint = {
    container_name   = "subscription-baseline"
    key              = "subscriptions/${var.subscription_id}/subscription-baseline.tfstate"
    use_azuread_auth = true
  }
}
