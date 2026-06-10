# Input guardrails that are evaluated during plan. These prevent optional
# subscription-baseline features from becoming silent no-ops when required ALZ
# shared-service inputs are missing.
resource "terraform_data" "input_guard" {
  input = {
    enable_activity_log_diagnostics  = var.enable_activity_log_diagnostics
    log_analytics_workspace_id       = var.log_analytics_workspace_id
    approved_log_workspace_subs      = var.approved_log_analytics_workspace_subscription_ids
    monthly_budget_amount            = var.monthly_budget_amount
    budget_start_date                = var.budget_start_date
    budget_contact_emails            = var.budget_contact_emails
    cost_export_storage_container_id = var.cost_export_storage_container_id
    approved_cost_storage_subs       = var.approved_cost_export_storage_subscription_ids
    cost_export_recurrence_from      = var.cost_export_recurrence_from
    cost_export_recurrence_to        = var.cost_export_recurrence_to
  }

  lifecycle {
    precondition {
      condition     = !var.enable_activity_log_diagnostics || var.log_analytics_workspace_id != ""
      error_message = "enable_activity_log_diagnostics is true, so log_analytics_workspace_id must reference an existing central workspace."
    }

    precondition {
      condition = (
        !var.enable_activity_log_diagnostics ||
        contains(local.normalized_log_analytics_workspace_subscription_ids, local.log_analytics_workspace_subscription_id)
      )
      error_message = "enable_activity_log_diagnostics is true, so approved_log_analytics_workspace_subscription_ids must include the subscription that hosts log_analytics_workspace_id."
    }

    precondition {
      condition     = var.monthly_budget_amount == null || length(var.budget_contact_emails) > 0
      error_message = "monthly_budget_amount is set, so budget_contact_emails must contain at least one email address."
    }

    precondition {
      condition     = var.monthly_budget_amount == null || var.budget_start_date != ""
      error_message = "monthly_budget_amount is set, so budget_start_date must be explicit and future-dated at apply time."
    }

    precondition {
      condition     = var.cost_export_storage_container_id == "" || (var.cost_export_recurrence_from != "" && var.cost_export_recurrence_to != "")
      error_message = "cost_export_storage_container_id is set, so cost_export_recurrence_from and cost_export_recurrence_to must be explicit and future-dated at apply time."
    }

    precondition {
      condition = (
        var.cost_export_storage_container_id == "" ||
        contains(local.normalized_cost_export_storage_subscription_ids, local.cost_export_storage_subscription_id)
      )
      error_message = "cost_export_storage_container_id is set, so approved_cost_export_storage_subscription_ids must include the subscription that hosts the export storage container."
    }
  }
}
