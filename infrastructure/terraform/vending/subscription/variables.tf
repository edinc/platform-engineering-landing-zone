variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID used by the vending identity."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "vending_subscription_id" {
  type        = string
  description = "Subscription ID used by the vending deployment identity and backend access."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.vending_subscription_id))
    error_message = "vending_subscription_id must be a GUID."
  }
}

variable "location" {
  type        = string
  description = "Default Azure region for vended subscription resources."
  default     = "westeurope"
}

variable "subscription_alias_name" {
  type        = string
  description = "Subscription alias name used by Azure/lz-vending."

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{3,63}$", var.subscription_alias_name))
    error_message = "subscription_alias_name must be 3-63 characters containing letters, numbers, underscore, or hyphen."
  }
}

variable "subscription_display_name" {
  type        = string
  description = "Display name for the vended workload subscription."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9 _-]{1,61}[A-Za-z0-9]$", var.subscription_display_name))
    error_message = "subscription_display_name must be 3-63 display-safe characters."
  }
}

variable "subscription_billing_scope" {
  type        = string
  description = "EA/MCA/MPA billing scope used to create the subscription alias."

  validation {
    condition     = can(regex("^/providers/Microsoft\\.Billing/billingAccounts/.+", var.subscription_billing_scope))
    error_message = "subscription_billing_scope must be a Microsoft.Billing billing scope resource ID."
  }
}

variable "subscription_workload" {
  type        = string
  description = "Azure subscription workload type."

  validation {
    condition     = contains(["Production", "DevTest"], var.subscription_workload)
    error_message = "subscription_workload must be Production or DevTest."
  }
}

variable "management_group_id" {
  type        = string
  description = "Destination ALZ management group ID for the workload subscription."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.()/-]{2,90}$", var.management_group_id))
    error_message = "management_group_id must be a management group ID, not a display name."
  }
}

variable "owner" {
  type        = string
  description = "owner tag value and workload team slug."
}

variable "product" {
  type        = string
  description = "product tag value."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.product))
    error_message = "product must be a lowercase slug."
  }
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value."

  validation {
    condition     = can(regex("^cc-[a-z0-9-]{2,32}$", var.cost_center))
    error_message = "cost_center must start with cc- and contain lowercase letters, numbers, or hyphens."
  }
}

variable "data_classification" {
  type        = string
  description = "Data-classification tag value."

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "confidentiality" {
  type        = string
  description = "Confidentiality tag value."

  validation {
    condition     = contains(["low", "medium", "high"], var.confidentiality)
    error_message = "confidentiality must be low, medium, or high."
  }
}

variable "repo" {
  type        = string
  description = "GitHub repository recorded in mandatory tags."
  default     = "edinc/platform-engineering-landing-zone"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repo))
    error_message = "repo must be owner/repository."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto the mandatory tag baseline."
  default     = {}
}

variable "monthly_budget_amount" {
  type        = number
  description = "Monthly budget amount for the vended subscription."

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be positive."
  }
}

variable "budget_start_date" {
  type        = string
  description = "Budget start date as RFC3339 UTC, first day of a month."

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be a first-of-month UTC timestamp like 2026-07-01T00:00:00Z."
  }
}

variable "budget_end_date" {
  type        = string
  description = "Budget end date as RFC3339 UTC."

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", var.budget_end_date))
    error_message = "budget_end_date must be an RFC3339 UTC timestamp."
  }
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Email addresses notified for 80 percent actual and 100 percent forecasted budget thresholds."

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "budget_contact_emails must contain at least one address."
  }
}

variable "role_assignments" {
  type = map(object({
    principal_id      = string
    definition        = string
    relative_scope    = optional(string, "")
    condition         = optional(string, "")
    condition_version = optional(string, "")
  }))
  description = "Optional group-only role assignments created by lz-vending in the workload subscription."
  default     = {}

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) : can(regex("^[0-9a-fA-F-]{36}$", assignment.principal_id))
    ])
    error_message = "Every role assignment principal_id must be a group/service principal object ID GUID."
  }
}

variable "spoke_virtual_network" {
  type = object({
    name                    = string
    address_space           = list(string)
    hub_network_resource_id = optional(string, "")
    resource_group_name     = optional(string, "")
  })
  description = "Optional workload spoke VNet to create and peer to the Stage 03 hub."
  default     = null
}
