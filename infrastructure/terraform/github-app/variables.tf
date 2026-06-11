variable "seed_key_vault_id" {
  type        = string
  description = "Stage 01 seed Key Vault resource ID where the GitHub App private key is stored."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", var.seed_key_vault_id))
    error_message = "seed_key_vault_id must be a full Key Vault resource ID."
  }
}

variable "github_owner" {
  type        = string
  description = "GitHub owner or organization that owns the platform repositories."
  default     = "edinc"
}

variable "github_app_id" {
  type        = string
  description = "platform-vending-bot GitHub App ID. The app registration is created manually/API-first; Terraform stores its key and installation scope."

  validation {
    condition     = can(regex("^[0-9]+$", var.github_app_id))
    error_message = "github_app_id must be a numeric string."
  }
}

variable "github_app_installation_id" {
  type        = number
  description = "Installation ID for platform-vending-bot on github_owner."
}

variable "private_key_secret_name" {
  type        = string
  description = "Existing seed Key Vault secret name containing the GitHub App private key. The value is written outside Terraform so it never enters state."
  default     = "platform-vending-bot-private-key"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,127}$", var.private_key_secret_name))
    error_message = "private_key_secret_name must be a valid Key Vault secret name."
  }
}

variable "private_key_rotation_due_date" {
  type        = string
  description = "Non-secret rotation due date recorded for operators. The actual Key Vault secret expiration is set by the runbook's az keyvault secret set command."

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.private_key_rotation_due_date))
    error_message = "private_key_rotation_due_date must be YYYY-MM-DD."
  }
}

variable "installation_repository_names" {
  type        = list(string)
  description = "Repositories selected for platform-vending-bot installation. Must include this repo and platform-cluster-state."
  default = [
    "platform-engineering-landing-zone",
    "platform-cluster-state",
  ]

  validation {
    condition     = length(var.installation_repository_names) >= 2
    error_message = "installation_repository_names must include at least the platform repo and platform-cluster-state."
  }
}
