variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the platform subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  type        = string
  description = "Platform subscription ID hosting AKS, ACR, Key Vault, and the workload identity resource group."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the workload identity."
  default     = "westeurope"
}

variable "resource_group_name" {
  type        = string
  description = "Platform resource group where the workload identity is created."
}

variable "team_name" {
  type        = string
  description = "Team slug owning the namespace."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.team_name))
    error_message = "team_name must be a lowercase slug."
  }
}

variable "product" {
  type        = string
  description = "Product slug for labels and tags."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.product))
    error_message = "product must be a lowercase slug."
  }
}

variable "environment" {
  type        = string
  description = "Environment profile for the vended namespace."

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.environment)
    error_message = "environment must be demo, nonprod, or prod."
  }
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to vend."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.namespace))
    error_message = "namespace must be a DNS-safe lowercase slug."
  }
}

variable "service_account_name" {
  type        = string
  description = "ServiceAccount name bound to Azure Workload Identity."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.service_account_name))
    error_message = "service_account_name must be a DNS-safe lowercase slug."
  }
}

variable "entra_group_object_id" {
  type        = string
  description = "Entra group object ID bound to namespace edit RBAC."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.entra_group_object_id))
    error_message = "entra_group_object_id must be a GUID."
  }
}

variable "aks_oidc_issuer_url" {
  type        = string
  description = "AKS OIDC issuer URL from the Stage 04 platform stack."

  validation {
    condition     = startswith(var.aks_oidc_issuer_url, "https://")
    error_message = "aks_oidc_issuer_url must start with https://."
  }
}

variable "aks_cluster_id" {
  type        = string
  description = "AKS cluster resource ID used for namespace-scoped Azure RBAC."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.aks_cluster_id))
    error_message = "aks_cluster_id must be a full AKS managed cluster resource ID."
  }
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID that grants AcrPull to the workload identity."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.ContainerRegistry/registries/[^/]+$", var.acr_id))
    error_message = "acr_id must be a full Azure Container Registry resource ID."
  }
}

variable "key_vault_secret_ids" {
  type        = list(string)
  description = "Key Vault secret resource IDs that grant Key Vault Secrets User to the workload identity."

  validation {
    condition = alltrue([
      for id in var.key_vault_secret_ids : can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+/secrets/[^/]+$", id))
    ])
    error_message = "key_vault_secret_ids must contain full Key Vault secret resource IDs when provided."
  }
}

variable "resource_quota" {
  type = object({
    cpu_requests    = string
    memory_requests = string
    cpu_limits      = string
    memory_limits   = string
    pods            = number
  })
  description = "Namespace ResourceQuota values."

  validation {
    condition     = var.resource_quota.pods > 0
    error_message = "resource_quota.pods must be positive."
  }
}

variable "egress_allowlist_cidrs" {
  type        = list(string)
  description = "CIDR ranges allowed by the namespace outbound NetworkPolicy."

  validation {
    condition = length(var.egress_allowlist_cidrs) > 0 && alltrue([
      for cidr in var.egress_allowlist_cidrs :
      can(cidrhost(cidr, 0)) &&
      can(regex("^(10\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])|172\\.(1[6-9]|2[0-9]|3[0-1])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])|192\\.168\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9]))/(1[6-9]|2[0-9]|3[0-2])$", cidr))
    ])
    error_message = "egress_allowlist_cidrs must contain RFC1918 IPv4 CIDRs with /16 or narrower prefixes. Use the egress exception workflow for public or broader access."
  }
}

variable "cost_center" {
  type        = string
  description = "costCenter tag/label value."

  validation {
    condition     = can(regex("^cc-[a-z0-9-]{2,32}$", var.cost_center))
    error_message = "cost_center must start with cc- and contain lowercase letters, numbers, or hyphens."
  }
}

variable "on_call_rotation_id" {
  type        = string
  description = "On-call rotation identifier for labels."
}

variable "data_classification" {
  type        = string
  description = "Data classification label/tag."

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "extra_labels" {
  type        = map(string)
  description = "Additional labels merged onto Kubernetes manifests."
  default     = {}
}

variable "output_directory" {
  type        = string
  description = "Directory where Flux-compatible manifests are rendered."
  default     = "generated"
}
