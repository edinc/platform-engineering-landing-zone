variable "subscription_id" {
  type        = string
  description = "Azure subscription ID that hosts the workload resource group."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the Container App resource."
}

variable "resource_group_name" {
  type        = string
  description = "Protected platform workload resource group where the Container App and workload identity are created."
}

variable "component_id" {
  type        = string
  description = "Container App component slug."
  default     = "${{ values.componentId }}"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,19}[a-z0-9]$", var.component_id))
    error_message = "component_id must be a DNS-safe slug no longer than 21 characters so ca-<component>-<environment> stays within Azure Container Apps naming limits."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "${{ values.environment }}"

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.environment)
    error_message = "environment must be demo, nonprod, or prod."
  }
}

variable "container_app_environment_id" {
  type        = string
  description = "Existing ACA managed environment ID (a platform shared service) supplied by protected GitHub Environment variables. This template never creates a managed environment."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.App/managedEnvironments/[^/]+$", var.container_app_environment_id))
    error_message = "container_app_environment_id must be a full ACA managed environment resource ID."
  }
}

variable "image_digest" {
  type        = string
  description = "Signed digest reference deployed by CI, for example myacr.azurecr.io/apps/service@sha256:..."

  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+(/[A-Za-z0-9_.-]+)+@sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must be a digest-pinned ACR image reference."
  }
}

variable "acr_id" {
  type        = string
  description = "Platform ACR resource ID that grants AcrPull to the Container App identity."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.ContainerRegistry/registries/[^/]+$", var.acr_id))
    error_message = "acr_id must be a full Azure Container Registry resource ID."
  }
}

variable "acr_login_server" {
  type        = string
  description = "Platform ACR login server used by the Container App registry block."

  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+\\.azurecr\\.io$", var.acr_login_server))
    error_message = "acr_login_server must be an Azure Container Registry login server."
  }
}

variable "container_port" {
  type        = number
  description = "Container listening port."
  default     = ${{ values.port }}
}

variable "public_route" {
  type        = bool
  description = "Whether ACA ingress exposes a public route."
  default     = ${{ values.publicRoute }}
}

variable "scale_rule" {
  type        = string
  description = "Primary ACA scale rule."
  default     = "${{ values.scaleRule }}"

  validation {
    condition     = contains(["http", "queue", "cron"], var.scale_rule)
    error_message = "scale_rule must be http, queue, or cron."
  }
}

variable "queue_name" {
  type        = string
  description = "Protected Azure Storage Queue name used when scale_rule is queue."
  default     = ""

  validation {
    condition     = var.queue_name == "" || can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$", var.queue_name))
    error_message = "queue_name must be empty or a valid Azure Storage Queue name."
  }
}

variable "queue_storage_account_name" {
  type        = string
  description = "Protected Azure Storage account name used when scale_rule is queue."
  default     = ""

  validation {
    condition     = var.queue_storage_account_name == "" || can(regex("^[a-z0-9]{3,24}$", var.queue_storage_account_name))
    error_message = "queue_storage_account_name must be empty or a valid Azure Storage account name."
  }
}

variable "queue_storage_account_id" {
  type        = string
  description = "Protected Azure Storage account resource ID used when scale_rule is queue."
  default     = ""

  validation {
    condition     = var.queue_storage_account_id == "" || can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+$", var.queue_storage_account_id))
    error_message = "queue_storage_account_id must be empty or a full Azure Storage account resource ID."
  }
}

variable "max_replicas" {
  type        = number
  description = "Maximum ACA replicas."
  default     = 5
}

variable "tags" {
  type        = map(string)
  description = "Mandatory platform tags."
  default = {
    env                = "${{ values.environment }}"
    owner              = "${{ values.teamName }}"
    costCenter         = "${{ values.costCenter }}"
    product            = "${{ values.productName }}"
    dataClassification = "${{ values.dataClassification }}"
    confidentiality    = "${{ values.confidentiality }}"
    managedBy          = "terraform"
    repo               = "${{ values.githubOwner }}/${{ values.repoName }}"
  }
}
