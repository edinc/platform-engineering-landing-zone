locals {
  tags = merge(
    var.extra_tags,
    {
      env                = var.subscription_workload == "Production" ? "prod" : "nonprod"
      owner              = var.owner
      costCenter         = var.cost_center
      product            = var.product
      dataClassification = var.data_classification
      confidentiality    = var.confidentiality
      managedBy          = "terraform"
      repo               = var.repo
    }
  )

  budgets = {
    subscription = {
      amount            = var.monthly_budget_amount
      time_grain        = "Monthly"
      time_period_start = var.budget_start_date
      time_period_end   = var.budget_end_date
      relative_scope    = ""
      notifications = {
        actual_80 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 80
          threshold_type = "Actual"
          contact_emails = var.budget_contact_emails
        }
        forecast_100 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 100
          threshold_type = "Forecasted"
          contact_emails = var.budget_contact_emails
        }
      }
    }
  }

  virtual_networks = var.spoke_virtual_network == null ? {} : {
    workload = {
      name                = var.spoke_virtual_network.name
      address_space       = var.spoke_virtual_network.address_space
      resource_group_name = var.spoke_virtual_network.resource_group_name != "" ? var.spoke_virtual_network.resource_group_name : "rg-${var.subscription_alias_name}-network-${var.location}"

      hub_peering_enabled     = var.spoke_virtual_network.hub_network_resource_id != ""
      hub_network_resource_id = var.spoke_virtual_network.hub_network_resource_id
      resource_group_tags     = local.tags
      tags                    = local.tags
    }
  }
}
