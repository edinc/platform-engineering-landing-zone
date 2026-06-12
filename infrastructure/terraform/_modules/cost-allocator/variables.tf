variable "name_prefix" {
  type        = string
  description = "Lowercase name prefix used for cost allocator resources."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.name_prefix))
    error_message = "name_prefix must be 3-32 lowercase alphanumeric or hyphen characters."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that hosts the Function App and showback storage."
}

variable "location" {
  type        = string
  description = "Azure region for cost allocator resources."
}

variable "cost_export_storage_container_id" {
  type        = string
  description = "Existing ALZ-owned Cost Management export storage container resource ID."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+/blobServices/default/containers/[^/]+$", var.cost_export_storage_container_id))
    error_message = "cost_export_storage_container_id must be a full storage container resource ID."
  }
}

variable "cost_export_root_folder" {
  type        = string
  description = "Root folder inside the Cost Management export container."
  default     = "subscription"
}

variable "showback_container_name" {
  type        = string
  description = "Container name for generated showback CSV files."
  default     = "showback"
}

variable "storage_account_name" {
  type        = string
  description = "Optional storage account name for Function host state and showback output."
  default     = ""

  validation {
    condition     = var.storage_account_name == "" || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be empty or 3-24 lowercase alphanumeric characters."
  }
}

variable "storage_replication_type" {
  type        = string
  description = "Replication type for the cost allocator storage account."
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be a supported standard replication type."
  }
}

variable "service_plan_sku_name" {
  type        = string
  description = "Linux Function App service plan SKU. EP1+ supports zone balancing, VNet integration, and always_on."
  default     = "EP1"
}

variable "service_plan_worker_count" {
  type        = number
  description = "Number of Function App plan workers. Use at least 3 when zone balancing is enabled."
  default     = 3

  validation {
    condition     = var.service_plan_worker_count >= 1
    error_message = "service_plan_worker_count must be at least 1."
  }
}

variable "service_plan_zone_balancing_enabled" {
  type        = bool
  description = "Whether the Function App service plan balances workers across availability zones."
  default     = true
}

variable "python_version" {
  type        = string
  description = "Python runtime version for the Function App."
  default     = "3.12"
}

variable "function_package_path" {
  type        = string
  description = "Optional local ZIP package path for Function App deployment."
  default     = null
}

variable "schedule" {
  type        = string
  description = "Timer trigger schedule for nightly showback allocation."
  default     = "0 0 2 * * *"
}

variable "application_insights_connection_string" {
  type        = string
  description = "Optional Application Insights connection string for Function telemetry."
  default     = ""
  sensitive   = true
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether the Function App and storage account allow public network access. Set false only after private endpoints and Function VNet integration are wired."
  default     = false
}

variable "virtual_network_subnet_id" {
  type        = string
  description = "Optional subnet ID for Function App regional VNet integration."
  default     = ""
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Optional subnet ID for cost allocator storage private endpoints."
  default     = ""
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Private DNS zone IDs keyed by zone name for cost allocator storage private endpoints."
  default     = {}
}

variable "app_settings" {
  type        = map(string)
  description = "Additional Function App settings."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Mandatory platform tag map."
}
