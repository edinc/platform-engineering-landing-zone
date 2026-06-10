variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID that hosts platform groups."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  type        = string
  description = "Existing subscription ID where this repo may create subscription/RG-scoped role definitions and assignments."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "environment" {
  type        = string
  description = "Environment profile for PIM approval rules."
  default     = "nonprod"

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.environment)
    error_message = "environment must be one of demo, nonprod, or prod."
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

variable "app_team_names" {
  type        = list(string)
  description = "Application team slugs used to create pe-app-team-<name> security groups."
  default     = []

  validation {
    condition     = alltrue([for name in var.app_team_names : can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", name))])
    error_message = "app_team_names must be lowercase slugs, 3-32 chars, starting and ending with alphanumeric characters."
  }
}

variable "group_owners_object_ids" {
  type        = list(string)
  description = "Object IDs assigned as owners for every created Entra group. Defaults to the Terraform principal when empty."
  default     = []

  validation {
    condition     = alltrue([for id in var.group_owners_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "group_owners_object_ids must contain GUID object IDs."
  }
}

variable "enable_platform_operator_role" {
  type        = bool
  description = "Whether to create the Platform Operator custom role."
  default     = true
}

variable "platform_operator_role_name" {
  type        = string
  description = "Custom role display name. Leave empty to derive an environment-specific name and avoid tenant-wide name collisions."
  default     = ""

  validation {
    condition     = var.platform_operator_role_name == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9 _().-]{2,62}[A-Za-z0-9)]$", var.platform_operator_role_name))
    error_message = "platform_operator_role_name must be empty or a 4-64 character Azure role display name."
  }
}

variable "role_assignable_scopes" {
  type        = list(string)
  description = "Assignable scopes for the Platform Operator custom role. Defaults to the target subscription."
  default     = []

  validation {
    condition     = alltrue([for scope in var.role_assignable_scopes : startswith(scope, "/subscriptions/")])
    error_message = "role_assignable_scopes must be subscription, resource-group, or resource scopes under /subscriptions/. Management-group scopes are owned by the external ALZ."
  }
}

variable "enable_default_assignments" {
  type        = bool
  description = "Whether to create default Reader and Platform Operator group assignments."
  default     = true
}

variable "pim_enabled" {
  type        = bool
  description = "Whether default Platform Operator access is created as a PIM eligible assignment instead of an active assignment."
  default     = true
}

variable "pim_maximum_duration" {
  type        = string
  description = "Maximum PIM activation duration for Platform Operator."
  default     = "PT8H"

  validation {
    condition = contains([
      "PT30M", "PT1H", "PT1H30M", "PT2H", "PT2H30M", "PT3H", "PT3H30M",
      "PT4H", "PT4H30M", "PT5H", "PT5H30M", "PT6H", "PT6H30M", "PT7H",
      "PT7H30M", "PT8H",
    ], var.pim_maximum_duration)
    error_message = "pim_maximum_duration must be PT30M through PT8H in 30-minute increments."
  }
}

variable "pim_require_approval_for_prod" {
  type        = bool
  description = "Whether prod PIM activation requires approval from the approval group."
  default     = true
}

variable "pim_approval_group_key" {
  type        = string
  description = "Group key used as the PIM approver group when prod approval is required."
  default     = "platform_admins"
}

variable "additional_active_role_assignments" {
  type = map(object({
    group_key            = string
    scope                = string
    role_definition_name = optional(string)
    role_definition_id   = optional(string)
    description          = optional(string)
  }))
  description = "Additional active Azure RBAC assignments. The principal is selected by group_key, never by user object ID."
  default     = {}
}

variable "additional_pim_eligible_role_assignments" {
  type = map(object({
    group_key          = string
    scope              = string
    role_definition_id = string
    justification      = optional(string)
    duration_hours     = optional(number)
  }))
  description = "Additional PIM eligible RBAC assignments. role_definition_id must be a scoped role definition resource ID."
  default     = {}
}
