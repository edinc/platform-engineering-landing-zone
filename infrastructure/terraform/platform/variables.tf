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
  description = "Existing platform subscription ID that hosts AKS, ACR, Key Vault, Postgres, Service Bus, Front Door, and ACA shared services."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "profile" {
  type        = string
  description = "Deployment profile."
  default     = "nonprod"

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.profile)
    error_message = "profile must be one of demo, nonprod, or prod."
  }
}

variable "location" {
  type        = string
  description = "Primary Azure region for platform shared services."
  default     = "westeurope"
}

variable "paired_location" {
  type        = string
  description = "Paired/DR Azure region used for ACR geo-replication and DR documentation."
  default     = "northeurope"
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

variable "name_suffix" {
  type        = string
  description = "Globally unique lowercase suffix for globally-scoped resources such as ACR and Key Vault."

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.name_suffix))
    error_message = "name_suffix must be 2-8 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Platform resource group name. Leave empty to use the standard Stage 04 name."
  default     = ""
}

variable "platform_vnet_address_space" {
  type        = list(string)
  description = "Address space for the platform spoke virtual network."
  default     = ["10.30.0.0/16"]
}

variable "subnet_address_prefixes" {
  type        = map(string)
  description = "Address prefixes for Stage 04 platform subnets."
  default = {
    aks-system         = "10.30.0.0/22"
    aks-user           = "10.30.4.0/22"
    private-endpoints  = "10.30.8.0/24"
    postgres-delegated = "10.30.9.0/24"
    aca-infra          = "10.30.10.0/23"
    shared-ingress     = "10.30.12.0/24"
  }

  validation {
    condition = alltrue([
      for name in ["aks-system", "aks-user", "private-endpoints", "postgres-delegated", "aca-infra", "shared-ingress"] :
      contains(keys(var.subnet_address_prefixes), name)
    ])
    error_message = "subnet_address_prefixes must include aks-system, aks-user, private-endpoints, postgres-delegated, aca-infra, and shared-ingress."
  }
}

variable "firewall_private_ip_address" {
  type        = string
  description = "Stage 03 Azure Firewall private IP used as the default route next hop. Leave empty to skip UDR creation."
  default     = ""

  validation {
    condition     = var.firewall_private_ip_address == "" || can(cidrhost("${var.firewall_private_ip_address}/32", 0))
    error_message = "firewall_private_ip_address must be empty or a valid IPv4 address."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones used for AKS node pools and zone-capable services."
  default     = []

  validation {
    condition     = alltrue([for zone in var.availability_zones : can(regex("^[1-3]$", zone))])
    error_message = "availability_zones entries must be zone numbers 1, 2, or 3."
  }
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Private DNS zone IDs from Stage 03, keyed by zone name."
  default     = {}
}

variable "private_dns_zone_subscription_id" {
  type        = string
  description = "Subscription ID that owns private_dns_zone_ids. Defaults to the platform subscription; set to the connectivity subscription when Stage 03 owns central zones."
  default     = ""

  validation {
    condition     = var.private_dns_zone_subscription_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.private_dns_zone_subscription_id))
    error_message = "private_dns_zone_subscription_id must be empty or a GUID."
  }
}

variable "link_private_dns_zones" {
  type        = bool
  description = "Whether this stack links supplied Private DNS zones to the platform VNet using the dns provider alias."
  default     = true
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Optional Stage 03 hub private-endpoints subnet ID. Defaults to this stack's platform private-endpoints subnet when empty."
  default     = ""
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing Log Analytics workspace ID used for AKS Defender, ACA logs, and diagnostics where enabled."
  default     = ""

  validation {
    condition = (
      var.log_analytics_workspace_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_id))
    )
    error_message = "log_analytics_workspace_id must be empty or a full Log Analytics workspace resource ID."
  }
}

variable "enable_private_endpoints" {
  type        = bool
  description = "Whether to create Private Endpoints for supported PaaS resources."
  default     = true
}

variable "enable_aks" {
  type        = bool
  description = "Whether to create the private AKS cluster and default user node pool."
  default     = true
}

variable "kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version or minor alias. Null lets Azure choose the latest supported default."
  default     = null
}

variable "aks_admin_group_object_ids" {
  type        = list(string)
  description = "Entra group object IDs that receive AKS cluster admin through managed Entra integration."
  default     = []

  validation {
    condition     = alltrue([for id in var.aks_admin_group_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "aks_admin_group_object_ids must contain GUID object IDs."
  }
}

variable "aks_system_node_pool" {
  type = object({
    vm_size    = string
    node_count = number
  })
  description = "System node pool settings."
  default = {
    vm_size    = "Standard_D4ds_v5"
    node_count = 3
  }
}

variable "aks_user_node_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  description = "Default user node pool autoscaling settings."
  default = {
    vm_size   = "Standard_D4ds_v5"
    min_count = 1
    max_count = 5
  }
}

variable "aks_service_cidr" {
  type        = string
  description = "Kubernetes service CIDR."
  default     = "10.240.0.0/16"
}

variable "aks_dns_service_ip" {
  type        = string
  description = "Kubernetes DNS service IP inside aks_service_cidr."
  default     = "10.240.0.10"
}

variable "aks_pod_cidr" {
  type        = string
  description = "Overlay pod CIDR for Azure CNI Overlay."
  default     = "10.244.0.0/16"
}

variable "enable_aks_defender" {
  type        = bool
  description = "Whether to enable AKS Defender profile. Requires log_analytics_workspace_id."
  default     = false
}

variable "enable_managed_prometheus" {
  type        = bool
  description = "Whether to enable the AKS managed Prometheus profile. Requires later Azure Monitor workspace integration."
  default     = false
}

variable "enable_acr" {
  type        = bool
  description = "Whether to create Azure Container Registry."
  default     = true
}

variable "acr_geo_replication_locations" {
  type        = list(string)
  description = "ACR geo-replication locations. Premium SKU only; defaults to the paired region for non-demo profiles."
  default     = []
}

variable "acr_cache_rules" {
  type = map(object({
    source_repo = string
    target_repo = string
  }))
  description = "ACR Artifact Cache rules. Quay is intentionally excluded and handled by workflows/import-quay.yml."
  default = {
    mcr_pause = {
      source_repo = "mcr.microsoft.com/oss/kubernetes/pause"
      target_repo = "cache/mcr/oss/kubernetes/pause"
    }
    docker_nginx = {
      source_repo = "docker.io/library/nginx"
      target_repo = "cache/docker/library/nginx"
    }
    ghcr_actions_runner = {
      source_repo = "ghcr.io/actions/actions-runner"
      target_repo = "cache/ghcr/actions/actions-runner"
    }
  }
}

variable "enable_key_vault" {
  type        = bool
  description = "Whether to create the per-environment platform Key Vault."
  default     = true
}

variable "key_vault_sku" {
  type        = string
  description = "Key Vault SKU. Use premium for HSM-backed keys in HA Postgres environments."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "key_vault_sku must be standard or premium."
  }
}

variable "enable_postgres" {
  type        = bool
  description = "Whether to create PostgreSQL Flexible Server and the backstage database. Requires postgres_administrator_password."
  default     = false
}

variable "postgres_administrator_login" {
  type        = string
  description = "PostgreSQL administrator login used only when enable_postgres is true."
  default     = "pgadmin"
}

variable "postgres_administrator_password" {
  type        = string
  description = "PostgreSQL administrator password supplied through TF_VAR or a secret store. Never commit real values."
  default     = null
  sensitive   = true
}

variable "postgres_sku_name" {
  type        = string
  description = "PostgreSQL Flexible Server SKU."
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  type        = number
  description = "PostgreSQL storage size in MiB."
  default     = 32768
}

variable "enable_service_bus" {
  type        = bool
  description = "Whether to create the platform-internal Service Bus namespace."
  default     = true
}

variable "enable_front_door" {
  type        = bool
  description = "Whether to create Front Door Premium profile and WAF policy shell."
  default     = true
}

variable "enable_aca_environment" {
  type        = bool
  description = "Whether to create the ACA managed environment substrate."
  default     = true
}

variable "owner" {
  type        = string
  description = "owner tag value for platform resources."
  default     = "platform-engineering"
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value for platform resources."
  default     = "cc-platform"
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
