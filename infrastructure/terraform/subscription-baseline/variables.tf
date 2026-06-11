variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the target subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  type        = string
  description = "Existing Azure subscription ID to onboard/harden. The subscription is assumed to already be placed in the organization's Azure Landing Zone."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing central Log Analytics workspace resource ID used for subscription Activity Log diagnostics. Required when enable_activity_log_diagnostics is true."
  default     = ""

  validation {
    condition = (
      var.log_analytics_workspace_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_id))
    )
    error_message = "log_analytics_workspace_id must be empty or a full Log Analytics workspace resource ID."
  }
}

variable "enable_activity_log_diagnostics" {
  type        = bool
  description = "Whether to route subscription Activity Log categories to log_analytics_workspace_id."
  default     = false
}

variable "approved_log_analytics_workspace_subscription_ids" {
  type        = list(string)
  description = "Subscription IDs approved to host the central Log Analytics workspace used by this baseline. Required when enable_activity_log_diagnostics is true; prevents routing Activity Logs to an unapproved workspace."
  default     = []

  validation {
    condition = alltrue([
      for id in var.approved_log_analytics_workspace_subscription_ids : can(regex("^[0-9a-fA-F-]{36}$", id))
    ])
    error_message = "approved_log_analytics_workspace_subscription_ids must contain only GUID subscription IDs."
  }
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
  description = "Required Microsoft Defender for Cloud plan tiers on the target subscription, keyed per plan. Values are explicit to prevent accidental downgrades of an existing ALZ subscription from Standard to Free. Use Free only for the demo profile or an approved cost exception; use Standard for nonprod/prod where coverage is required."
  nullable    = false

  validation {
    condition = alltrue([
      for tier in values(var.defender_tiers) : contains(["Free", "Standard"], tier)
    ])
    error_message = "Every defender_tiers value must be Free or Standard."
  }
}

variable "defender_plan_subplans" {
  type        = map(string)
  description = "Optional Defender subplan overrides keyed by exact Microsoft.Security pricing resource type (for example Arm, KeyVaults, StorageAccounts). Use to preserve brownfield subplans discovered before import/apply."
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.defender_plan_subplans) :
      contains(["VirtualMachines", "Containers", "KeyVaults", "StorageAccounts", "SqlServers", "OpenSourceRelationalDatabases", "Arm", "Api"], key)
    ])
    error_message = "defender_plan_subplans keys must be one of the Defender pricing resource types managed by this stack."
  }
}

variable "defender_plan_extensions" {
  type = map(list(object({
    name                            = string
    additional_extension_properties = optional(map(string), {})
  })))
  description = "Optional Defender extension blocks keyed by exact Microsoft.Security pricing resource type. Use to preserve brownfield extensions discovered before import/apply."
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.defender_plan_extensions) :
      contains(["VirtualMachines", "Containers", "KeyVaults", "StorageAccounts", "SqlServers", "OpenSourceRelationalDatabases", "Arm", "Api"], key)
    ])
    error_message = "defender_plan_extensions keys must be one of the Defender pricing resource types managed by this stack."
  }
}

variable "monthly_budget_amount" {
  type        = number
  description = "Optional monthly budget amount for the target subscription. Set to null to skip budget creation."
  default     = null

  validation {
    condition     = var.monthly_budget_amount == null || var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be null or a positive number."
  }
}

variable "budget_start_date" {
  type        = string
  description = "Budget time-period start. Must be the first day of a month in RFC3339 and not in the past at apply time. Required when monthly_budget_amount is set."
  default     = ""

  validation {
    condition     = var.budget_start_date == "" || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", var.budget_start_date))
    error_message = "budget_start_date must be empty or an RFC3339 UTC timestamp like 2026-07-01T00:00:00Z."
  }
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Email addresses notified when the subscription budget threshold is crossed. Required when monthly_budget_amount is set."
  default     = []
}

variable "cost_export_storage_container_id" {
  type        = string
  description = "Optional existing storage container resource ID that receives daily Cost Management exports. Leave empty to skip export creation. The container is assumed to be owned/hardened by the existing ALZ/platform foundation."
  default     = ""

  validation {
    condition = (
      var.cost_export_storage_container_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+/blobServices/default/containers/[^/]+$", var.cost_export_storage_container_id))
    )
    error_message = "cost_export_storage_container_id must be empty or a full storage container resource ID."
  }
}

variable "approved_cost_export_storage_subscription_ids" {
  type        = list(string)
  description = "Subscription IDs approved to host the Cost Management export storage container. Required when cost_export_storage_container_id is set; prevents exporting cost data to an unapproved storage account."
  default     = []

  validation {
    condition = alltrue([
      for id in var.approved_cost_export_storage_subscription_ids : can(regex("^[0-9a-fA-F-]{36}$", id))
    ])
    error_message = "approved_cost_export_storage_subscription_ids must contain only GUID subscription IDs."
  }
}

variable "cost_export_root_folder" {
  type        = string
  description = "Root folder path inside the existing cost export container."
  default     = "subscription"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9/_-]{0,127}$", var.cost_export_root_folder))
    error_message = "cost_export_root_folder must be 1-128 characters and contain only letters, numbers, slash, underscore, and hyphen."
  }
}

variable "cost_export_recurrence_from" {
  type        = string
  description = "Cost Management export schedule start (RFC3339). Azure requires this to be in the future at apply time. Required when cost_export_storage_container_id is set."
  default     = ""

  validation {
    condition     = var.cost_export_recurrence_from == "" || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", var.cost_export_recurrence_from))
    error_message = "cost_export_recurrence_from must be empty or an RFC3339 UTC timestamp like 2026-07-01T00:00:00Z."
  }
}

variable "cost_export_recurrence_to" {
  type        = string
  description = "Cost Management export schedule end (RFC3339). Required when cost_export_storage_container_id is set."
  default     = ""

  validation {
    condition     = var.cost_export_recurrence_to == "" || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", var.cost_export_recurrence_to))
    error_message = "cost_export_recurrence_to must be empty or an RFC3339 UTC timestamp like 2030-07-01T00:00:00Z."
  }
}
