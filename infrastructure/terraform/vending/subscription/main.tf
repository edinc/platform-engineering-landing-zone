resource "terraform_data" "input_guard" {
  input = {
    management_group_id        = var.management_group_id
    subscription_billing_scope = var.subscription_billing_scope
    budget_contact_emails      = var.budget_contact_emails
    spoke_virtual_network      = var.spoke_virtual_network
  }

  lifecycle {
    precondition {
      condition     = length(var.budget_contact_emails) > 0
      error_message = "Subscription vending requires budget_contact_emails for the 80 percent and 100 percent thresholds."
    }

    precondition {
      condition = (
        var.spoke_virtual_network == null ||
        alltrue([for cidr in var.spoke_virtual_network.address_space : can(cidrhost(cidr, 0))])
      )
      error_message = "spoke_virtual_network.address_space entries must be valid CIDR ranges."
    }
  }
}

module "lz_vending" {
  source = "git::https://github.com/Azure/terraform-azurerm-lz-vending.git?ref=dee26d39d5d3fc5fb78feb7fe26d63e4d956c9be" # v4.1.5

  location = var.location

  disable_telemetry = true

  subscription_alias_enabled = true
  subscription_use_azapi     = true
  subscription_alias_name    = var.subscription_alias_name
  subscription_billing_scope = var.subscription_billing_scope
  subscription_display_name  = var.subscription_display_name
  subscription_workload      = var.subscription_workload
  subscription_tags          = local.tags

  subscription_management_group_association_enabled = true
  subscription_management_group_id                  = var.management_group_id

  network_watcher_resource_group_enabled = true

  budget_enabled = true
  budgets        = local.budgets

  role_assignment_enabled = length(var.role_assignments) > 0
  role_assignments        = var.role_assignments

  virtual_network_enabled = length(local.virtual_networks) > 0
  virtual_networks        = local.virtual_networks

  depends_on = [terraform_data.input_guard]
}
