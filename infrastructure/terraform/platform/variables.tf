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

variable "aks_host_encryption_enabled" {
  type        = bool
  description = "Whether AKS node pools enable host encryption. Keep true for production; set false only for demo subscriptions where Microsoft.Compute/EncryptionAtHost is unavailable."
  default     = true
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

variable "enable_gitops" {
  type        = bool
  description = "Whether to install the Microsoft-managed Flux extension and root Flux configuration for the platform cluster."
  default     = false
}

variable "gitops_flux_namespace" {
  type        = string
  description = "Namespace where the AKS Flux extension installs Flux controllers."
  default     = "flux-system"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.gitops_flux_namespace))
    error_message = "gitops_flux_namespace must be a DNS-safe lowercase namespace name."
  }
}

variable "cluster_state_repository_url" {
  type        = string
  description = "HTTPS or SSH URL for the Flux-watched platform-cluster-state repository. Defaults to github_owner/platform-cluster-state when empty."
  default     = ""

  validation {
    condition = (
      var.cluster_state_repository_url == "" ||
      can(regex("^(https://|ssh://|git@).+", var.cluster_state_repository_url))
    )
    error_message = "cluster_state_repository_url must be empty or start with https://, ssh://, or git@."
  }
}

variable "cluster_state_branch" {
  type        = string
  description = "Branch in platform-cluster-state reconciled by the platform Flux configuration."
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]+$", var.cluster_state_branch))
    error_message = "cluster_state_branch must contain only letters, numbers, underscores, dots, slashes, and hyphens."
  }
}

variable "cluster_state_root_path" {
  type        = string
  description = "Path in platform-cluster-state reconciled by the root Flux Kustomization. Defaults to clusters/overlays/<profile> when empty."
  default     = ""

  validation {
    condition = (
      var.cluster_state_root_path == "" ||
      can(regex("^clusters/overlays/(demo|nonprod|prod)$", var.cluster_state_root_path))
    )
    error_message = "cluster_state_root_path must be empty or one of clusters/overlays/demo, clusters/overlays/nonprod, or clusters/overlays/prod."
  }
}

variable "gitops_repository_provider" {
  type        = string
  description = "Optional OIDC provider for Flux Git repository auth. Use GitHub, Azure, or Generic only when the cluster-state repository supports it."
  default     = ""

  validation {
    condition     = contains(["", "GitHub", "Azure", "Generic"], var.gitops_repository_provider)
    error_message = "gitops_repository_provider must be empty, GitHub, Azure, or Generic."
  }
}

variable "platform_root_domain" {
  type        = string
  description = "Root DNS zone for platform hostnames, for example platform.contoso.com."
  default     = ""

  validation {
    condition     = var.platform_root_domain == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$", var.platform_root_domain))
    error_message = "platform_root_domain must be empty or a valid DNS name."
  }
}

variable "azure_dns_resource_group_name" {
  type        = string
  description = "Resource group that owns the Azure DNS zones used by cert-manager and external-dns."
  default     = ""
}

variable "cert_manager_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by cert-manager for Azure DNS and Key Vault CSI access."
  default     = ""

  validation {
    condition     = var.cert_manager_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.cert_manager_workload_identity_client_id))
    error_message = "cert_manager_workload_identity_client_id must be empty or a GUID."
  }
}

variable "external_dns_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by external-dns for Azure DNS writes."
  default     = ""

  validation {
    condition     = var.external_dns_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.external_dns_workload_identity_client_id))
    error_message = "external_dns_workload_identity_client_id must be empty or a GUID."
  }
}

variable "external_secrets_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by External Secrets Operator for Azure Key Vault reads when ClusterSecretStores are configured."
  default     = ""

  validation {
    condition     = var.external_secrets_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.external_secrets_workload_identity_client_id))
    error_message = "external_secrets_workload_identity_client_id must be empty or a GUID."
  }
}

variable "aso_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by Azure Service Operator."
  default     = ""

  validation {
    condition     = var.aso_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.aso_workload_identity_client_id))
    error_message = "aso_workload_identity_client_id must be empty or a GUID."
  }
}

variable "application_insights_ingestion_endpoint" {
  type        = string
  description = "Application Insights OTLP HTTP ingestion endpoint for the OpenTelemetry collector."
  default     = ""

  validation {
    condition     = var.application_insights_ingestion_endpoint == "" || startswith(var.application_insights_ingestion_endpoint, "https://")
    error_message = "application_insights_ingestion_endpoint must be empty or start with https://."
  }
}

variable "gitops_sync_interval_seconds" {
  type        = number
  description = "Flux Git source and Kustomization sync interval in seconds."
  default     = 300

  validation {
    condition     = var.gitops_sync_interval_seconds >= 60
    error_message = "gitops_sync_interval_seconds must be at least 60."
  }
}

variable "gitops_timeout_seconds" {
  type        = number
  description = "Flux Git source and Kustomization reconciliation timeout in seconds."
  default     = 600

  validation {
    condition     = var.gitops_timeout_seconds >= 60
    error_message = "gitops_timeout_seconds must be at least 60."
  }
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
  description = "ACR Artifact Cache rules. Docker Hub and Quay are intentionally excluded from defaults because current ACR cache requires credentials for Docker and does not support Quay; use workflows/import-quay.yml or supply authenticated rules explicitly."
  default = {
    mcr_pause = {
      source_repo = "mcr.microsoft.com/oss/kubernetes/pause"
      target_repo = "cache/mcr/oss/kubernetes/pause"
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
