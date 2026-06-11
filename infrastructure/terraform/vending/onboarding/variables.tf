variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the externally-created subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  type        = string
  description = "Externally-created subscription ID handed to Stage 02."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "management_group_id" {
  type        = string
  description = "Expected ALZ management group ID confirmed by the external vending owner."
}

variable "alz_placement_evidence" {
  type        = string
  description = "Change ticket, PR, or owner confirmation proving the subscription is in the expected ALZ management group."

  validation {
    condition     = length(var.alz_placement_evidence) >= 8
    error_message = "alz_placement_evidence must reference the approval/change evidence for management-group placement."
  }
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Central Log Analytics workspace resource ID passed to Stage 02."
  default     = ""
}

variable "defender_tiers" {
  type = object({
    virtual_machines = string
    containers       = string
    key_vaults       = string
    storage_accounts = string
    sql_servers      = string
    open_source_dbs  = string
    resource_manager = string
    apis             = string
  })
  description = "Defender plan tiers passed to the Stage 02 subscription-baseline stack."
}

variable "monthly_budget_amount" {
  type        = number
  description = "Optional monthly budget amount passed to Stage 02."
  default     = null
}

variable "budget_start_date" {
  type        = string
  description = "Budget start date passed to Stage 02 when monthly_budget_amount is set."
  default     = ""
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Budget contacts passed to Stage 02."
  default     = []
}

variable "output_directory" {
  type        = string
  description = "Directory where generated Stage 02 handoff files are written."
  default     = "generated"
}
