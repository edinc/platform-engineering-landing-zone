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
  description = "Status check contexts required by branch protection. Empty keeps the seed repo usable before Stage 06 workflows exist."
  default     = []
}
