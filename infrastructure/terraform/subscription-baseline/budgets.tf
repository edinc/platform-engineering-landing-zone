# Optional monthly Cost Management budget for the target subscription.
resource "azurerm_consumption_budget_subscription" "this" {
  count = var.monthly_budget_amount == null ? 0 : 1

  name            = "budget-pe-subscription"
  subscription_id = local.subscription_scope
  amount          = var.monthly_budget_amount
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
}
