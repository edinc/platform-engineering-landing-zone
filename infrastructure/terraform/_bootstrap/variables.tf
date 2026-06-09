variable "subscription_id" {
  type        = string
  description = "Bootstrap subscription ID that hosts Terraform remote state, the seed Key Vault, and bootstrap monitoring."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the bootstrap subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for bootstrap resources."
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
  description = "Globally unique disambiguator appended to globally scoped names (storage account, Key Vault). Keep it short and stable."

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.name_suffix))
    error_message = "name_suffix must be 2-8 lowercase alphanumeric characters."
  }

  validation {
    condition     = length("kv-pe-boot-${var.location_short}-${var.name_suffix}") <= 24
    error_message = "The derived Key Vault name kv-pe-boot-<location_short>-<name_suffix> exceeds Azure's 24-character limit; shorten name_suffix or location_short."
  }
}

variable "github_owner" {
  type        = string
  description = "GitHub owner (user or organization) that hosts the platform repository."
  default     = "edinc"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name for the platform landing zone."
  default     = "platform-engineering-landing-zone"
}

variable "state_containers" {
  type        = list(string)
  description = "Blob containers (one per stage plus per-profile env state) created in the Terraform state account."
  default = [
    "bootstrap",
    "alz",
    "connectivity",
    "identity",
    "platform",
    "vending",
    "cicd",
    "gitops",
    "observability",
    "backstage",
    "onboarding",
    "golden-paths",
    "dr",
    "envs-demo",
    "envs-nonprod",
    "envs-prod",
  ]

  validation {
    condition     = contains(var.state_containers, "bootstrap")
    error_message = "state_containers must include the bootstrap container used by this stack's own backend."
  }
}

variable "key_vault_sku" {
  type        = string
  description = "Seed Key Vault SKU. Use premium for HSM-backed keys."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "key_vault_sku must be standard or premium."
  }
}

variable "key_type" {
  type        = string
  description = "State CMK key type. Use RSA-HSM for HSM-backed protection (requires key_vault_sku = premium)."
  default     = "RSA"

  validation {
    condition     = contains(["RSA", "RSA-HSM"], var.key_type)
    error_message = "key_type must be RSA or RSA-HSM (RSA-HSM requires key_vault_sku = premium)."
  }

  validation {
    condition     = var.key_type != "RSA-HSM" || var.key_vault_sku == "premium"
    error_message = "key_type = RSA-HSM requires key_vault_sku = premium; HSM-backed keys are not supported on the standard SKU."
  }
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Soft-delete retention (days) for the seed Key Vault and state blobs."
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "allowed_ip_cidrs" {
  type        = list(string)
  description = "Phase 1 break-glass operator IP ranges allowed through the state account and Key Vault firewalls. Terraform owns and drift-detects this baseline. GitHub-hosted runner egress is added just-in-time via runner_ip_cidrs by the bootstrap workflow."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_ip_cidrs : !endswith(cidr, "/32")])
    error_message = "Use a bare IP (for example 203.0.113.10) instead of a /32; the Azure storage firewall normalizes /32 to a bare IP, which then shows a permanent diff."
  }
}

variable "runner_ip_cidrs" {
  type        = list(string)
  description = "Ephemeral GitHub-hosted runner egress IP(s) the bootstrap workflow allowlists for the duration of a CI run (TF_VAR_runner_ip_cidrs). Merged with allowed_ip_cidrs so Terraform never evicts its own remote-state access mid-apply. Leave empty for local runs."
  default     = []
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Retention (days) for the bootstrap Log Analytics workspace used by break-glass alerting."
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730."
  }
}

variable "break_glass_upns" {
  type        = list(string)
  description = "User principal names of the break-glass accounts monitored for sign-in activity. Empty disables the alert rule until accounts are provisioned."
  default     = []
}

variable "alert_email_receivers" {
  type        = list(string)
  description = "Email addresses notified when a break-glass account signs in."
  default     = []
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value for bootstrap resources."
  default     = "cc-platform"
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto the mandatory tag set."
  default     = {}
}
