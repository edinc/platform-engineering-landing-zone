# Per-subscription monthly Cost Management budgets. Created only for the
# subscriptions listed in var.subscription_budgets (empty by default), so the
# stack stays brownfield-safe and does not assume specific subscriptions exist.
resource "azurerm_consumption_budget_subscription" "this" {
  for_each = var.subscription_budgets

  name            = "budget-pe-${each.key}"
  subscription_id = "/subscriptions/${each.value.subscription_id}"
  amount          = each.value.amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }

  # Azure requires at least one notification contact per budget. Fail at plan
  # (only when a budget is actually being created) instead of surfacing an opaque
  # apply-time API error.
  lifecycle {
    precondition {
      condition     = length(var.budget_contact_emails) > 0
      error_message = "subscription_budgets is set but budget_contact_emails is empty; set at least one notification email."
    }
  }
}
