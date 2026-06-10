locals {
  name_prefix = "pe-${var.profile}-${var.location_short}"
  resource_group_name = (
    var.resource_group_name != "" ? var.resource_group_name : "rg-pe-${var.profile}-platform-${var.location_short}"
  )

  acr_name         = "acrpe${var.profile}${var.location_short}${var.name_suffix}"
  key_vault_name   = "kv-pe-${var.profile}-${var.location_short}-${var.name_suffix}"
  service_bus_name = "sb-${local.name_prefix}-${var.name_suffix}"
  postgres_name    = "pg-${local.name_prefix}-${var.name_suffix}"

  acr_geo_replication_locations = (
    length(var.acr_geo_replication_locations) > 0 ? var.acr_geo_replication_locations : (
      var.profile == "demo" ? [] : [var.paired_location]
    )
  )

  service_bus_sku       = "Premium"
  service_bus_capacity  = 1
  service_bus_partition = 1

  route_table_enabled = var.firewall_private_ip_address != ""
  private_endpoint_subnet_id = (
    var.private_endpoint_subnet_id != "" ? var.private_endpoint_subnet_id : azurerm_subnet.platform["private-endpoints"].id
  )

  aks_private_dns_zone_name      = "privatelink.${var.location}.azmk8s.io"
  postgres_private_dns_zone_name = "privatelink.postgres.database.azure.com"

  private_endpoint_required_zones = merge(
    var.enable_acr ? { acr = ["privatelink.azurecr.io"] } : {},
    var.enable_key_vault ? { key_vault = ["privatelink.vaultcore.azure.net"] } : {},
    var.enable_service_bus ? { service_bus = ["privatelink.servicebus.windows.net"] } : {},
  )

  private_endpoint_specs = merge(
    var.enable_private_endpoints && var.enable_acr && contains(keys(var.private_dns_zone_ids), "privatelink.azurecr.io") ? {
      acr = {
        resource_id            = azurerm_container_registry.platform[0].id
        subresource_names      = ["registry"]
        private_dns_zone_names = ["privatelink.azurecr.io"]
      }
    } : {},
    var.enable_private_endpoints && var.enable_key_vault && contains(keys(var.private_dns_zone_ids), "privatelink.vaultcore.azure.net") ? {
      key_vault = {
        resource_id            = azurerm_key_vault.platform[0].id
        subresource_names      = ["vault"]
        private_dns_zone_names = ["privatelink.vaultcore.azure.net"]
      }
    } : {},
    var.enable_private_endpoints && var.enable_service_bus && contains(keys(var.private_dns_zone_ids), "privatelink.servicebus.windows.net") ? {
      service_bus = {
        resource_id            = azurerm_servicebus_namespace.platform[0].id
        subresource_names      = ["namespace"]
        private_dns_zone_names = ["privatelink.servicebus.windows.net"]
      }
    } : {},
  )

  private_dns_zone_links = var.link_private_dns_zones ? {
    for zone_name, zone_id in var.private_dns_zone_ids : zone_name => {
      resource_group_name = regex("^/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/Microsoft\\.Network/privateDnsZones/([^/]+)$", zone_id)[0]
      zone_name           = regex("^/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/Microsoft\\.Network/privateDnsZones/([^/]+)$", zone_id)[1]
    }
  } : {}

  subnet_delegations = {
    postgres-delegated = {
      name = "postgres-flexible"
      service_delegation = {
        name    = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    aca-infra = {
      name = "container-apps"
      service_delegation = {
        name = "Microsoft.App/environments"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
        ]
      }
    }
  }

  route_table_subnet_keys = [
    "aks-system",
    "aks-user",
    "aca-infra",
    "shared-ingress",
  ]

  diagnostic_targets = var.log_analytics_workspace_id == "" ? {} : merge(
    var.enable_acr ? {
      acr = azurerm_container_registry.platform[0].id
    } : {},
    var.enable_key_vault ? {
      key_vault = azurerm_key_vault.platform[0].id
    } : {},
    var.enable_service_bus ? {
      service_bus = azurerm_servicebus_namespace.platform[0].id
    } : {},
    var.enable_front_door ? {
      front_door_profile = azurerm_cdn_frontdoor_profile.platform[0].id
    } : {},
    var.enable_aks ? {
      aks = azurerm_kubernetes_cluster.platform[0].id
    } : {},
    var.enable_postgres ? {
      postgres = azurerm_postgresql_flexible_server.platform[0].id
    } : {},
  )

  aca_workload_profiles = var.profile == "prod" ? [
    {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
      minimum_count         = null
      maximum_count         = null
    },
    {
      name                  = "prod-d4"
      workload_profile_type = "D4"
      minimum_count         = 1
      maximum_count         = 3
    },
    ] : [
    {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
      minimum_count         = null
      maximum_count         = null
    },
  ]

  tags = merge(
    {
      env                = var.profile
      owner              = var.owner
      costCenter         = var.cost_center
      product            = "landing-zone"
      dataClassification = "internal"
      confidentiality    = var.profile == "prod" ? "high" : "low"
      managedBy          = "terraform"
      repo               = "${var.github_owner}/${var.github_repo}"
    },
    var.extra_tags,
  )
}
