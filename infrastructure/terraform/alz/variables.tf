variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID that owns the management-group hierarchy."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "management_subscription_id" {
  type        = string
  description = "Subscription ID for the management subscription that hosts the central Log Analytics workspace, Defender for Cloud, budgets, and Cost Management exports. This is the provider subscription for this stack."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.management_subscription_id))
    error_message = "management_subscription_id must be a GUID."
  }
}

variable "connectivity_subscription_id" {
  type        = string
  description = "Optional subscription ID to place under the connectivity management group. Empty leaves the MG unassociated (brownfield-safe)."
  default     = ""

  validation {
    condition     = var.connectivity_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.connectivity_subscription_id))
    error_message = "connectivity_subscription_id must be empty or a GUID."
  }
}

variable "identity_subscription_id" {
  type        = string
  description = "Optional subscription ID to place under the identity management group. Empty leaves the MG unassociated (brownfield-safe)."
  default     = ""

  validation {
    condition     = var.identity_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.identity_subscription_id))
    error_message = "identity_subscription_id must be empty or a GUID."
  }
}

variable "corp_subscription_id" {
  type        = string
  description = "Optional first workload subscription ID to place under the landingzones/corp management group. Empty leaves the MG unassociated (brownfield-safe)."
  default     = ""

  validation {
    condition     = var.corp_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.corp_subscription_id))
    error_message = "corp_subscription_id must be empty or a GUID."
  }
}

variable "associate_management_subscription" {
  type        = bool
  description = "Whether to associate the management subscription under the management MG. Leave false on brownfield tenants where the subscription is still under another MG or the root, and move it through a reviewed change (see brownfield runbook). MG moves have blast radius: child policy assignments re-evaluate against the new ancestry."
  default     = false
}

variable "location" {
  type        = string
  description = "Azure region for regional resources (Log Analytics workspace, Cost Management export storage)."
  default     = "westeurope"
}

variable "location_short" {
  type        = string
  description = "Short region token used in resource names (for example weu for westeurope)."
  default     = "weu"

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.location_short))
    error_message = "location_short must be 2-6 lowercase alphanumeric characters."
  }
}

variable "name_suffix" {
  type        = string
  description = "Globally unique disambiguator appended to the Cost Management export storage account name. Keep it short and stable."

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.name_suffix))
    error_message = "name_suffix must be 2-8 lowercase alphanumeric characters."
  }

  validation {
    condition     = length("stpealzcost${var.location_short}${var.name_suffix}") <= 24
    error_message = "The derived storage account name stpealzcost<location_short><name_suffix> exceeds Azure's 24-character limit; shorten name_suffix or location_short."
  }
}

variable "management_group_prefix" {
  type        = string
  description = "Prefix for management-group names (the immutable MG ID, not the display name)."
  default     = "mg-pe-"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.management_group_prefix))
    error_message = "management_group_prefix must be 1-40 lowercase alphanumeric or hyphen characters."
  }
}

variable "root_management_group_id" {
  type        = string
  description = "Full resource ID of the parent for the top-level 'alz' management group. Defaults to the Tenant Root Group derived from tenant_id. Override only to nest the hierarchy under an existing intermediate MG (brownfield)."
  default     = ""
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value for ALZ platform resources."
  default     = "cc-platform"
}

variable "github_owner" {
  type        = string
  description = "GitHub owner that hosts the platform repository (repo tag)."
  default     = "edinc"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name for the platform landing zone (repo tag)."
  default     = "platform-engineering-landing-zone"
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto the mandatory tag set."
  default     = {}
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Retention (days) for the central Log Analytics workspace."
  default     = 90

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730."
  }
}

variable "cis_enforce" {
  type        = bool
  description = "Whether the CIS Microsoft Azure Foundations Benchmark v2 initiative is enforced (Default) or evaluation-only (DoNotEnforce). Defaults to false so the only active Deny at Stage 02 is the tag baseline (acceptance criteria 2 and 3). Flip to true after the exemption inventory is drained and the assignment identity has been granted the initiative's remediation roles (ADR-0011, ADR-0027)."
  default     = false
}

variable "tag_baseline_enforce" {
  type        = bool
  description = "Whether the tag-baseline initiative is enforced (Default, Deny active) or evaluation-only (DoNotEnforce). Defaults to true to satisfy acceptance criterion 3. Set to false only during a documented brownfield grace period (brownfield runbook)."
  default     = true
}

variable "private_link_effect" {
  type        = string
  description = "Effect for the private-link-required initiative. Stays at Audit during the Stage 02 grace period. Only the Storage and PostgreSQL members honor this effect; the Key Vault and Container Registry members are audit-only built-ins with no Deny effect, so Deny tightens Storage and PostgreSQL while KV/ACR stay audit-only."
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.private_link_effect)
    error_message = "private_link_effect must be Audit, Deny, or Disabled."
  }
}

variable "aks_effect" {
  type        = string
  description = "Effect for the aks-baseline initiative. Capped at Audit/Disabled; in-cluster enforcement is handled by Kyverno (ADR-0036)."
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Disabled"], var.aks_effect)
    error_message = "aks_effect must be Audit or Disabled."
  }
}

variable "defender_tiers" {
  type = object({
    virtual_machines = optional(string, "Free")
    containers       = optional(string, "Free")
    key_vaults       = optional(string, "Free")
    storage_accounts = optional(string, "Free")
    sql_servers      = optional(string, "Free")
    open_source_dbs  = optional(string, "Free")
    resource_manager = optional(string, "Free")
    apis             = optional(string, "Free")
  })
  description = "Microsoft Defender for Cloud plan tiers on the management subscription, keyed per plan. Use Free for the demo profile and Standard for nonprod/prod. Each value must be Free or Standard."
  default     = {}

  validation {
    condition = alltrue([
      for tier in values(var.defender_tiers) : contains(["Free", "Standard"], tier)
    ])
    error_message = "Every defender_tiers value must be Free or Standard."
  }
}

variable "diagnostics_policy_definition_id" {
  type        = string
  description = "Optional full resource ID of a diagnostic-settings DeployIfNotExists policy or initiative to assign at the platform MG, routing logs to the central workspace. Empty leaves diagnostics DINE unassigned and surfaces a check-block warning. Pair with diagnostics_policy_parameters for the policy's parameter names."
  default     = ""
}

variable "diagnostics_policy_parameters" {
  type        = map(any)
  description = "Parameter values for the diagnostics DINE assignment (for example { logAnalytics = { value = \"<workspace-id>\" } }). The central workspace ID is exported as log_analytics_workspace_id for convenience."
  default     = {}
}

variable "subscription_budgets" {
  type = map(object({
    subscription_id = string
    amount          = number
  }))
  description = "Per-subscription monthly Cost Management budgets, keyed by a short name. Empty creates no budgets (cost exports remain the Stage 02 acceptance criterion). Example: { management = { subscription_id = \"...\", amount = 500 } }."
  default     = {}

  validation {
    condition = alltrue([
      for b in values(var.subscription_budgets) : can(regex("^[0-9a-fA-F-]{36}$", b.subscription_id)) && b.amount > 0
    ])
    error_message = "Each subscription_budgets entry needs a GUID subscription_id and a positive amount."
  }
}

variable "budget_start_date" {
  type        = string
  description = "Budget time-period start. Must be the first day of a month in RFC3339 and not in the past (Azure requirement). Only used when subscription_budgets is non-empty."
  default     = "2026-07-01T00:00:00Z"
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Email addresses notified when a subscription budget threshold is crossed. Required (at least one) whenever subscription_budgets is non-empty, since Azure mandates a notification contact per budget."
  default     = []
}

variable "cost_export_recurrence_from" {
  type        = string
  description = "Cost Management export schedule start (RFC3339). Azure requires this to be in the future at apply time; adjust if apply reports a validation error."
  default     = "2026-07-01T00:00:00Z"
}

variable "cost_export_recurrence_to" {
  type        = string
  description = "Cost Management export schedule end (RFC3339)."
  default     = "2030-07-01T00:00:00Z"
}

variable "cost_export_retention_days" {
  type        = number
  description = "Lifecycle retention (days) before exported cost blobs are deleted from the ADLS Gen2 account."
  default     = 365

  validation {
    condition     = var.cost_export_retention_days >= 30 && var.cost_export_retention_days <= 3650
    error_message = "cost_export_retention_days must be between 30 and 3650."
  }
}

variable "cost_management_principal_id" {
  type        = string
  description = "Optional object ID of the Cost Management export service principal to grant Storage Blob Data Contributor on the export account. Leave empty to grant the role out of band (the v4 export resource has no managed identity block)."
  default     = ""

  validation {
    condition     = var.cost_management_principal_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.cost_management_principal_id))
    error_message = "cost_management_principal_id must be empty or a GUID object ID."
  }
}

variable "cost_export_storage_ip_rules" {
  type        = list(string)
  description = "Operator IP ranges allowed through the Cost Management export storage firewall (default-deny). Use bare IPs, not /32. A Private Endpoint replaces this in the Stage 03 connectivity stage (ADR-0048 phased-connectivity pattern)."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.cost_export_storage_ip_rules : !endswith(cidr, "/32")])
    error_message = "Use a bare IP (for example 203.0.113.10) instead of a /32; the Azure storage firewall normalizes /32 to a bare IP and then shows a permanent diff."
  }
}
