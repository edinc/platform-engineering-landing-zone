variable "subscription_id" {
  type        = string
  description = "Demo workload subscription ID."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the demo subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for demo resources."
  default     = "westeurope"
}

variable "location_short" {
  type        = string
  description = "Short region token used in resource names."
  default     = "weu"

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.location_short))
    error_message = "location_short must be 2-6 lowercase alphanumeric characters."
  }
}

variable "owner" {
  type        = string
  description = "owner tag value for the demo workload."
  default     = "platform-engineering"
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value for the demo workload."
  default     = "cc-demo"
}

variable "github_owner" {
  type        = string
  description = "GitHub owner that hosts the platform repository (repo tag)."
  default     = "edinc"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (repo tag)."
  default     = "platform-engineering-landing-zone"
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto the mandatory tag set."
  default     = {}
}
