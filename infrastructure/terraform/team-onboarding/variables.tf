variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID that hosts app-team groups."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "platform_group_prefix" {
  type        = string
  description = "Prefix for platform and app-team group display names."
  default     = "pe"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,16}$", var.platform_group_prefix))
    error_message = "platform_group_prefix must be 2-16 lowercase letters, numbers, or hyphens."
  }
}

variable "team_name" {
  type        = string
  description = "Application team slug."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.team_name))
    error_message = "team_name must be a lowercase slug, 3-32 chars, starting and ending with alphanumeric characters."
  }
}

variable "product_name" {
  type        = string
  description = "Primary product slug for the team."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.product_name))
    error_message = "product_name must be a lowercase slug no longer than 22 characters."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost center assigned to the team."

  validation {
    condition     = can(regex("^cc-[a-z0-9-]{2,32}$", var.cost_center))
    error_message = "cost_center must start with cc- and contain lowercase letters, numbers, or hyphens."
  }
}

variable "on_call_rotation_id" {
  type        = string
  description = "On-call rotation identifier for the team."

  validation {
    condition     = length(var.on_call_rotation_id) >= 3 && length(var.on_call_rotation_id) <= 128
    error_message = "on_call_rotation_id must be 3-128 characters."
  }
}

variable "data_classification" {
  type        = string
  description = "Highest data classification approved for the team."

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "group_owners_object_ids" {
  type        = list(string)
  description = "Object IDs assigned as owners for the created Entra group. Defaults to the Terraform principal when empty."
  default     = []

  validation {
    condition     = alltrue([for id in var.group_owners_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "group_owners_object_ids must contain GUID object IDs."
  }
}

variable "github_owner" {
  type        = string
  description = "GitHub owner or organization that owns the application-team repositories."
  default     = "edinc"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_owner))
    error_message = "github_owner must be a valid GitHub owner name."
  }
}

variable "github_team_name" {
  type        = string
  description = "GitHub team slug. Defaults to app-team-<team_name>."
  default     = ""

  validation {
    condition     = var.github_team_name == "" || can(regex("^app-team-[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.github_team_name))
    error_message = "github_team_name must be empty or match app-team-<slug>."
  }
}

variable "github_parent_team_id" {
  type        = number
  description = "Optional parent GitHub team ID for organization nesting."
  default     = null
}

variable "github_repository_permissions" {
  type        = map(string)
  description = "Least-privilege repository permissions keyed by repository name. Self-service onboarding only supports pull or triage."
  default     = {}

  validation {
    condition     = alltrue([for permission in values(var.github_repository_permissions) : contains(["pull", "triage"], permission)])
    error_message = "github_repository_permissions values must be pull or triage. Use a separately approved repository administration path for push, maintain, or admin."
  }

  validation {
    condition     = alltrue([for repository in keys(var.github_repository_permissions) : can(regex("^[A-Za-z0-9_.-]+$", repository))])
    error_message = "github_repository_permissions keys must be repository names, not owner/repo pairs."
  }
}
