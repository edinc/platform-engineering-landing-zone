variable "tenant_id" {
  type        = string
  description = "Entra ID tenant ID for the connectivity subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  type        = string
  description = "Existing connectivity subscription ID that hosts the hub network."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "profile" {
  type        = string
  description = "Deployment profile. demo uses NAT Gateway only; nonprod/prod use Azure Firewall Premium."
  default     = "nonprod"

  validation {
    condition     = contains(["demo", "nonprod", "prod"], var.profile)
    error_message = "profile must be one of demo, nonprod, or prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region for connectivity resources."
  default     = "swedencentral"
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

variable "resource_group_name" {
  type        = string
  description = "Connectivity resource group name. Leave empty to use the standard connectivity & egress name."
  default     = ""
}

variable "hub_vnet_address_space" {
  type        = list(string)
  description = "Address space for the hub virtual network."
  default     = ["10.20.0.0/16"]

  validation {
    condition     = length(var.hub_vnet_address_space) > 0
    error_message = "hub_vnet_address_space must contain at least one CIDR."
  }
}

variable "subnet_address_prefixes" {
  type        = map(string)
  description = "Address prefixes for required connectivity & egress hub subnets. AzureFirewallManagementSubnet is added separately when forced tunneling is enabled."
  default = {
    GatewaySubnet       = "10.20.0.0/27"
    AzureFirewallSubnet = "10.20.1.0/26"
    private-endpoints   = "10.20.2.0/24"
    shared-services     = "10.20.3.0/24"
  }

  validation {
    condition = alltrue([
      for name in ["GatewaySubnet", "AzureFirewallSubnet", "private-endpoints", "shared-services"] :
      contains(keys(var.subnet_address_prefixes), name)
    ])
    error_message = "subnet_address_prefixes must include GatewaySubnet, AzureFirewallSubnet, private-endpoints, and shared-services."
  }
}

variable "firewall_forced_tunneling_enabled" {
  type        = bool
  description = "Whether to create AzureFirewallManagementSubnet and a management public IP for forced tunneling."
  default     = false
}

variable "firewall_base_policy_id" {
  type        = string
  description = "Optional existing ALZ parent Firewall Policy resource ID inherited by the connectivity & egress child Firewall Policy."
  default     = ""

  validation {
    condition = (
      var.firewall_base_policy_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/firewallPolicies/[^/]+$", var.firewall_base_policy_id))
    )
    error_message = "firewall_base_policy_id must be empty or a full Azure Firewall Policy resource ID."
  }
}

variable "firewall_management_subnet_address_prefix" {
  type        = string
  description = "Address prefix for AzureFirewallManagementSubnet when forced tunneling is enabled."
  default     = "10.20.1.64/26"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for zonal firewall public IPs. Demo NAT uses the first zone only because NAT Gateway is single-zone."
  default     = []

  validation {
    condition     = alltrue([for zone in var.availability_zones : can(regex("^[1-3]$", zone))])
    error_message = "availability_zones entries must be zone numbers 1, 2, or 3."
  }
}

variable "spoke_virtual_network_ids" {
  type        = map(string)
  description = "Existing spoke virtual network IDs to hub-peer and link to every connectivity & egress Private DNS zone. Reverse peering is created only for spokes in the connectivity subscription; cross-subscription reverse peering is owned by vending/workload stacks."
  default     = {}

  validation {
    condition = alltrue([
      for id in values(var.spoke_virtual_network_ids) :
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", id))
    ])
    error_message = "spoke_virtual_network_ids values must be full virtual network resource IDs."
  }
}

variable "workload_subnet_ids" {
  type        = map(string)
  description = "Existing workload subnet IDs in this connectivity subscription that should receive the default route to Azure Firewall. Tenancy vending consumes the exported firewall_route_table_id for workload subscriptions."
  default     = {}

  validation {
    condition = alltrue([
      for id in values(var.workload_subnet_ids) :
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", id))
    ])
    error_message = "workload_subnet_ids values must be full subnet resource IDs."
  }
}

variable "workload_subnet_source_prefixes" {
  type        = map(string)
  description = "Source CIDRs for workload_subnet_ids, keyed identically. Each prefix must be present in firewall_allowlist_source_addresses before the subnet is routed to the firewall."
  default     = {}

  validation {
    condition = alltrue([
      for cidr in values(var.workload_subnet_source_prefixes) :
      can(cidrhost(cidr, 0)) &&
      can(tonumber(split("/", cidr)[1])) &&
      tonumber(split("/", cidr)[1]) >= 20 &&
      tonumber(split("/", cidr)[1]) <= 32 &&
      cidr != "0.0.0.0/0" &&
      !contains(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], cidr)
    ])
    error_message = "workload_subnet_source_prefixes must contain valid, specific IPv4 CIDRs (/20 or narrower), not broad internet/RFC1918 supernets."
  }
}

variable "firewall_allowlist_source_addresses" {
  type        = list(string)
  description = "Source CIDRs allowed to use the curated egress allowlist. Defaults to the shared-services subnet; add approved workload prefixes as the tenancy vending capability onboards spokes."
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.firewall_allowlist_source_addresses :
      can(cidrhost(cidr, 0)) &&
      can(tonumber(split("/", cidr)[1])) &&
      tonumber(split("/", cidr)[1]) >= 20 &&
      tonumber(split("/", cidr)[1]) <= 32 &&
      cidr != "0.0.0.0/0" &&
      !contains(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], cidr)
    ])
    error_message = "firewall_allowlist_source_addresses must contain valid, specific IPv4 CIDRs (/20 or narrower), not broad internet/RFC1918 supernets."
  }
}

variable "additional_private_dns_zone_names" {
  type        = list(string)
  description = "Additional Private DNS zones required by workload-specific PaaS services. Keep OpenAI/Cosmos out until a workload uses them."
  default     = []
}

variable "enable_monitor_private_link_scope" {
  type        = bool
  description = "Whether to create the Azure Monitor Private Link Scope used by observability resources."
  default     = false
}

variable "monitor_private_link_ingestion_access_mode" {
  type        = string
  description = "AMPLS ingestion access mode. PrivateOnly keeps monitoring ingestion on private paths once linked resources are onboarded."
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.monitor_private_link_ingestion_access_mode)
    error_message = "monitor_private_link_ingestion_access_mode must be Open or PrivateOnly."
  }
}

variable "monitor_private_link_query_access_mode" {
  type        = string
  description = "AMPLS query access mode. Defaults to PrivateOnly; use Open only as a documented brownfield exception while onboarding monitor resources."
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.monitor_private_link_query_access_mode)
    error_message = "monitor_private_link_query_access_mode must be Open or PrivateOnly."
  }
}

variable "monitor_linked_resource_ids" {
  type        = list(string)
  description = "Log Analytics workspaces, Application Insights components, or Data Collection Endpoints linked into AMPLS."
  default     = []
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Optional Log Analytics workspace ID for Azure Firewall policy insights."
  default     = ""

  validation {
    condition = (
      var.log_analytics_workspace_id == "" ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_id))
    )
    error_message = "log_analytics_workspace_id must be empty or a full Log Analytics workspace resource ID."
  }
}

variable "private_endpoints" {
  type = map(object({
    resource_id            = string
    subresource_names      = list(string)
    private_dns_zone_names = list(string)
    manual_approval        = optional(bool, false)
    request_message        = optional(string, "")
  }))
  description = "Private Endpoints created in the hub private-endpoints subnet, including Azure foundation state account and seed Key Vault retrofit entries."
  default     = {}
}

variable "owner" {
  type        = string
  description = "owner tag value for connectivity resources."
  default     = "platform-engineering"
}

variable "cost_center" {
  type        = string
  description = "costCenter tag value for connectivity resources."
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
