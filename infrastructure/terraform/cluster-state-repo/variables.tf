variable "github_owner" {
  type        = string
  description = "GitHub owner or organization that will host the cluster-state repository."
  default     = "edinc"
}

variable "repository_name" {
  type        = string
  description = "Name of the Flux-watched cluster-state repository."
  default     = "platform-cluster-state"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.repository_name))
    error_message = "repository_name must be a valid GitHub repository name."
  }
}

variable "repository_visibility" {
  type        = string
  description = "Repository visibility."
  default     = "private"

  validation {
    condition     = contains(["private", "internal"], var.repository_visibility)
    error_message = "repository_visibility must be private or internal."
  }
}

variable "default_branch" {
  type        = string
  description = "Default branch for the cluster-state repository."
  default     = "main"
}

variable "codeowners" {
  type        = list(string)
  description = "CODEOWNERS entries for the cluster-state repository."
  default     = ["* @edinc/platform-engineering"]
}

variable "required_status_checks" {
  type        = list(string)
  description = "Status check contexts required by branch protection. Empty keeps the seed repo usable before supply chain & CI/CD workflows exist."
  default     = []
}

variable "repository_profile" {
  type        = string
  description = "Deployment profile for repository controls. Branch protection may only be disabled for demo integration repositories with an explicit bypass reason."
  default     = "prod"

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.repository_profile)
    error_message = "repository_profile must be demo, nonprod, or prod."
  }
}

variable "enable_branch_protection" {
  type        = bool
  description = "Whether to configure default-branch protection. Keep true for organizations/plans that support branch protection on private repositories; set false only for constrained integration repos where GitHub rejects branch protection."
  default     = true
}

variable "branch_protection_bypass_reason" {
  type        = string
  description = "Required reason when enable_branch_protection is false for a demo integration repository."
  default     = ""
}

variable "stage07_seed_files_enabled" {
  type        = bool
  description = "Whether Terraform should write the expanded GitOps platform seed files directly to the default branch. Enable only during first repository creation before branch protection is active; use PR-based GitOps promotion afterwards."
  default     = false
}
