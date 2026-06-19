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
  default     = "swedencentral"
}

variable "paired_location" {
  type        = string
  description = "Paired/DR Azure region used for ACR geo-replication and DR documentation."
  default     = "swedensouth"
}

variable "location_short" {
  type        = string
  description = "Short region token used in resource names."
  default     = "sec"

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
    aks-system           = "10.30.0.0/22"
    aks-user             = "10.30.4.0/22"
    private-endpoints    = "10.30.8.0/24"
    postgres-delegated   = "10.30.9.0/24"
    aca-infra            = "10.30.10.0/23"
    shared-ingress       = "10.30.12.0/24"
    function-integration = "10.30.13.0/27"
  }

  validation {
    condition = alltrue(concat(
      [
        for name in ["aks-system", "aks-user", "private-endpoints", "postgres-delegated", "aca-infra", "shared-ingress"] :
        contains(keys(var.subnet_address_prefixes), name)
      ],
      var.enable_cost_allocator ? [contains(keys(var.subnet_address_prefixes), "function-integration")] : [],
    ))
    error_message = "subnet_address_prefixes must include aks-system, aks-user, private-endpoints, postgres-delegated, aca-infra, and shared-ingress. enable_cost_allocator also requires function-integration."
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

variable "aks_os_disk_type" {
  type        = string
  description = "AKS node pool OS disk type. Keep Ephemeral where the chosen VM SKU supports it; use Managed only for constrained demo subscriptions whose allowed SKUs do not provide enough temp/cache disk."
  default     = "Ephemeral"

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.aks_os_disk_type)
    error_message = "aks_os_disk_type must be Ephemeral or Managed."
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

variable "azure_monitor_workspace_id" {
  type        = string
  description = "Azure Monitor workspace resource ID used by Managed Prometheus alert rule groups."
  default     = ""

  validation {
    condition = (
      var.azure_monitor_workspace_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Monitor/accounts/[^/]+$", var.azure_monitor_workspace_id))
    )
    error_message = "azure_monitor_workspace_id must be empty or a full Azure Monitor workspace resource ID."
  }
}

variable "enable_aks_node_auto_provisioning" {
  type        = bool
  description = "Whether to enable AKS Node Auto-Provisioning on the platform cluster. Use after validating regional quota and AKS API support."
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

variable "cluster_state_ssh_private_key_base64" {
  type        = string
  description = "Base64-encoded SSH private key used by Flux to clone a private cluster-state repository. Store this in a protected secret, not in committed tfvars."
  default     = ""
  sensitive   = true

  validation {
    condition     = var.cluster_state_ssh_private_key_base64 == "" || can(base64decode(var.cluster_state_ssh_private_key_base64))
    error_message = "cluster_state_ssh_private_key_base64 must be empty or valid base64."
  }
}

variable "cluster_state_ssh_known_hosts_base64" {
  type        = string
  description = "Base64-encoded known_hosts content for the SSH host used by the Flux cluster-state repository."
  default     = ""

  validation {
    condition     = var.cluster_state_ssh_known_hosts_base64 == "" || can(base64decode(var.cluster_state_ssh_known_hosts_base64))
    error_message = "cluster_state_ssh_known_hosts_base64 must be empty or valid base64."
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

variable "backstage_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by the Backstage Kubernetes service account for Entra auth, Azure Blob TechDocs, and AKS API reads."
  default     = ""

  validation {
    condition     = var.backstage_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.backstage_workload_identity_client_id))
    error_message = "backstage_workload_identity_client_id must be empty or a GUID."
  }
}

variable "backstage_workload_identity_principal_id" {
  type        = string
  description = "Managed identity principal object ID used for Backstage Azure Blob TechDocs RBAC."
  default     = ""

  validation {
    condition     = var.backstage_workload_identity_principal_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.backstage_workload_identity_principal_id))
    error_message = "backstage_workload_identity_principal_id must be empty or a GUID."
  }
}

variable "backstage_catalog_reconciler_workload_identity_client_id" {
  type        = string
  description = "Managed identity client ID used by the Backstage catalog reconciler service account."
  default     = ""

  validation {
    condition     = var.backstage_catalog_reconciler_workload_identity_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.backstage_catalog_reconciler_workload_identity_client_id))
    error_message = "backstage_catalog_reconciler_workload_identity_client_id must be empty or a GUID."
  }
}

variable "backstage_catalog_reconciler_workload_identity_principal_id" {
  type        = string
  description = "Managed identity principal object ID used for catalog reconciler Key Vault RBAC."
  default     = ""

  validation {
    condition     = var.backstage_catalog_reconciler_workload_identity_principal_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.backstage_catalog_reconciler_workload_identity_principal_id))
    error_message = "backstage_catalog_reconciler_workload_identity_principal_id must be empty or a GUID."
  }
}

variable "backstage_application_team_group_refs" {
  type        = string
  description = "Comma-separated Backstage group refs allowed to receive app-team permissions, for example group:default/pe-app-team-payments."
  default     = ""
}

variable "backstage_application_team_group_map_json" {
  type        = string
  description = "JSON object mapping Backstage app-team group refs to cost/team slugs, for example {\"group:default/pe-app-team-payments\":\"payments\"}."
  default     = "{}"

  validation {
    condition     = can(jsondecode(var.backstage_application_team_group_map_json))
    error_message = "backstage_application_team_group_map_json must be valid JSON."
  }
}

variable "backstage_microsoft_graph_group_object_ids" {
  type        = set(string)
  description = "Immutable Entra group object IDs that Backstage may ingest from Microsoft Graph for RBAC identity data."
  default     = []

  validation {
    condition     = alltrue([for id in var.backstage_microsoft_graph_group_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "backstage_microsoft_graph_group_object_ids entries must be GUID object IDs."
  }
}

variable "backstage_microsoft_auth_client_id" {
  type        = string
  description = "Microsoft Entra application client ID used by the Backstage Microsoft auth provider. This is separate from the pod Workload Identity client ID."
  default     = ""

  validation {
    condition     = var.backstage_microsoft_auth_client_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.backstage_microsoft_auth_client_id))
    error_message = "backstage_microsoft_auth_client_id must be empty or a GUID."
  }
}

variable "backstage_chart_version" {
  type        = string
  description = "Backstage Helm chart version published to the platform ACR OCI repository."
  default     = "0.1.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+([-+][A-Za-z0-9.-]+)?$", var.backstage_chart_version))
    error_message = "backstage_chart_version must be a semantic version."
  }
}

variable "backstage_chart_digest" {
  type        = string
  description = "Digest of the signed Backstage Helm chart promoted by the Stage 06 supply chain."
  default     = ""

  validation {
    condition     = var.backstage_chart_digest == "" || can(regex("^sha256:[a-f0-9]{64}$", var.backstage_chart_digest))
    error_message = "backstage_chart_digest must be empty or a sha256 digest."
  }
}

variable "backstage_image_repository" {
  type        = string
  description = "Backstage image repository. Defaults to <platform ACR login server>/platform/backstage when ACR is enabled."
  default     = ""

  validation {
    condition     = var.backstage_image_repository == "" || can(regex("^[A-Za-z0-9.-]+(/[A-Za-z0-9_.-]+)+$", var.backstage_image_repository))
    error_message = "backstage_image_repository must be empty or a container repository path without tag or digest."
  }
}

variable "backstage_image_digest" {
  type        = string
  description = "Digest of the signed Backstage image promoted by the Stage 06 supply chain."
  default     = ""

  validation {
    condition     = var.backstage_image_digest == "" || can(regex("^sha256:[a-f0-9]{64}$", var.backstage_image_digest))
    error_message = "backstage_image_digest must be empty or a sha256 digest."
  }
}

variable "backstage_catalog_reconciler_image_repository" {
  type        = string
  description = "Catalog reconciler image repository. Defaults to <platform ACR login server>/platform/backstage-catalog-reconciler when ACR is enabled."
  default     = ""

  validation {
    condition     = var.backstage_catalog_reconciler_image_repository == "" || can(regex("^[A-Za-z0-9.-]+(/[A-Za-z0-9_.-]+)+$", var.backstage_catalog_reconciler_image_repository))
    error_message = "backstage_catalog_reconciler_image_repository must be empty or a container repository path without tag or digest."
  }
}

variable "backstage_catalog_reconciler_image_digest" {
  type        = string
  description = "Digest of the signed catalog reconciler image promoted by the Stage 06 supply chain."
  default     = ""

  validation {
    condition     = var.backstage_catalog_reconciler_image_digest == "" || can(regex("^sha256:[a-f0-9]{64}$", var.backstage_catalog_reconciler_image_digest))
    error_message = "backstage_catalog_reconciler_image_digest must be empty or a sha256 digest."
  }
}

variable "backstage_postgres_host" {
  type        = string
  description = "Postgres host for Backstage. Defaults to the platform PostgreSQL Flexible Server FQDN when enable_postgres is true."
  default     = ""
}

variable "backstage_postgres_user" {
  type        = string
  description = "Postgres user used by Backstage. Prefer an Entra-authenticated principal mapped to the Backstage workload identity."
  default     = ""
}

variable "backstage_postgres_auth_mode" {
  type        = string
  description = "Backstage Postgres authentication mode. Use entra only after PostgreSQL Flexible Server Entra authentication and user mapping are configured."
  default     = "password"

  validation {
    condition     = contains(["password", "entra"], var.backstage_postgres_auth_mode)
    error_message = "backstage_postgres_auth_mode must be password or entra."
  }
}

variable "backstage_aks_apiserver_url" {
  type        = string
  description = "AKS API server URL used by the Backstage Kubernetes plugin. Defaults to the private AKS FQDN when empty."
  default     = ""

  validation {
    condition     = var.backstage_aks_apiserver_url == "" || startswith(var.backstage_aks_apiserver_url, "https://")
    error_message = "backstage_aks_apiserver_url must be empty or start with https://."
  }
}

variable "backstage_cost_showback_container_url" {
  type        = string
  description = "Stage 08 cost showback container URL consumed by the Backstage Cost Insights configuration."
  default     = ""

  validation {
    condition     = var.backstage_cost_showback_container_url == "" || startswith(var.backstage_cost_showback_container_url, "https://")
    error_message = "backstage_cost_showback_container_url must be empty or start with https://."
  }
}

variable "backstage_cost_showback_container_id" {
  type        = string
  description = "Stage 08 cost showback container resource ID used to grant Backstage read access. Defaults to the cost allocator module output when enabled."
  default     = ""

  validation {
    condition = (
      var.backstage_cost_showback_container_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+/blobServices/default/containers/[^/]+$", var.backstage_cost_showback_container_id))
    )
    error_message = "backstage_cost_showback_container_id must be empty or a full storage container resource ID."
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

variable "enable_alerting_action_groups" {
  type        = bool
  description = "Whether to create Stage 08 Azure Monitor Action Groups for SEV1/SEV2/SEV3 routing."
  default     = false
}

variable "enable_cost_allocator" {
  type        = bool
  description = "Whether to deploy the Stage 08 cost allocator Function App that consumes the existing Cost Management export container."
  default     = false
}

variable "enable_backstage" {
  type        = bool
  description = "Whether to deploy the Stage 09 Backstage MVP through a dedicated Flux configuration."
  default     = false
}

variable "enable_techdocs_storage" {
  type        = bool
  description = "Whether to create the Stage 09 Azure Blob storage account and private container for Backstage TechDocs."
  default     = false
}

variable "techdocs_storage_container_name" {
  type        = string
  description = "Blob container name used by Backstage TechDocs."
  default     = "techdocs"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.techdocs_storage_container_name))
    error_message = "techdocs_storage_container_name must be a DNS-safe lowercase storage container name."
  }
}

variable "techdocs_publisher_principal_ids" {
  type        = set(string)
  description = "Principal object IDs for Stage 06 TechDocs publisher workflows that can write to the TechDocs container."
  default     = []

  validation {
    condition     = alltrue([for principal_id in var.techdocs_publisher_principal_ids : can(regex("^[0-9a-fA-F-]{36}$", principal_id))])
    error_message = "techdocs_publisher_principal_ids entries must be GUID object IDs."
  }
}

variable "cost_export_storage_container_id" {
  type        = string
  description = "Existing ALZ-owned Cost Management export storage container resource ID consumed by the cost allocator."
  default     = ""

  validation {
    condition = (
      var.cost_export_storage_container_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+/blobServices/default/containers/[^/]+$", var.cost_export_storage_container_id))
    )
    error_message = "cost_export_storage_container_id must be empty or a full storage container resource ID."
  }
}

variable "cost_export_root_folder" {
  type        = string
  description = "Root folder path inside the existing Cost Management export container."
  default     = "subscription"
}

variable "cost_allocator_function_package_path" {
  type        = string
  description = "Optional local ZIP package path for the cost allocator Function App deployment."
  default     = null
}

variable "cost_allocator_public_network_access_enabled" {
  type        = bool
  description = "Whether the cost allocator Function App and storage allow public network access. Set false only after private endpoints and Function VNet integration are wired."
  default     = false
}

variable "cost_allocator_application_insights_connection_string" {
  type        = string
  description = "Optional Application Insights connection string for cost allocator telemetry."
  default     = ""
  sensitive   = true
}

variable "alerting_teams_webhook_url" {
  type        = string
  description = "Demo-profile Teams webhook URL for Azure Monitor Action Group notifications. Supply out of band; never commit a real URL."
  default     = ""
  sensitive   = true

  validation {
    condition     = var.alerting_teams_webhook_url == "" || startswith(var.alerting_teams_webhook_url, "https://")
    error_message = "alerting_teams_webhook_url must be empty or start with https://."
  }
}

variable "alerting_email_receivers" {
  type = list(object({
    name          = string
    email_address = string
  }))
  description = "Optional email receivers added to every Stage 08 Action Group."
  default     = []
}

variable "alerting_pagerduty_itsm" {
  type = object({
    workspace_id         = string
    connection_id        = string
    region               = string
    ticket_configuration = string
  })
  description = "PagerDuty ITSM connector settings for non-demo Action Groups. workspace_id format is '<subscription id>|<workspace id>'."
  default     = null
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

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must contain only letters, numbers, and hyphens so it is safe in generated GitHub URLs and Kyverno trust regexes."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (repo tag)."
  default     = "platform-engineering-landing-zone"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.github_repo))
    error_message = "github_repo must contain only letters, numbers, underscores, and hyphens so it is safe in generated GitHub URLs and Kyverno trust regexes."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto the mandatory tag set."
  default     = {}
}
