locals {
  name_prefix = "pe-${var.profile}-${var.location_short}"
  resource_group_name = (
    var.resource_group_name != "" ? var.resource_group_name : "rg-pe-${var.profile}-platform-${var.location_short}"
  )

  acr_name              = "acrpe${var.profile}${var.location_short}${var.name_suffix}"
  key_vault_name        = "kv-pe-${var.profile}-${var.location_short}-${var.name_suffix}"
  service_bus_name      = "sb-${local.name_prefix}-${var.name_suffix}"
  postgres_name         = "pg-${local.name_prefix}-${var.name_suffix}"
  techdocs_storage_name = lower("stpe${var.profile}${var.location_short}${var.name_suffix}")
  techdocs_container_name = (
    var.techdocs_storage_container_name != "" ? var.techdocs_storage_container_name : "techdocs"
  )
  backstage_image_repository = (
    var.backstage_image_repository != "" ? var.backstage_image_repository : try("${azurerm_container_registry.platform[0].login_server}/platform/backstage", "")
  )
  backstage_catalog_reconciler_image_repository = (
    var.backstage_catalog_reconciler_image_repository != "" ? var.backstage_catalog_reconciler_image_repository : try("${azurerm_container_registry.platform[0].login_server}/platform/backstage-catalog-reconciler", "")
  )
  backstage_public_ingress_enabled = local.backstage_enabled && var.enable_backstage_public_ingress
  backstage_public_ingress_allowed_cidr = (
    trimspace(var.backstage_public_ingress_allowed_cidr) != "" ? trimspace(var.backstage_public_ingress_allowed_cidr) : "127.0.0.1/32"
  )
  backstage_postgres_host = (
    var.backstage_postgres_host != "" ? var.backstage_postgres_host : try(azurerm_postgresql_flexible_server.platform[0].fqdn, "")
  )
  backstage_postgres_user = (
    var.backstage_postgres_user != "" ? var.backstage_postgres_user : (
      var.backstage_postgres_auth_mode == "password" ? var.postgres_administrator_login : "backstage"
    )
  )
  backstage_aks_apiserver_url = (
    var.backstage_aks_apiserver_url != "" ? var.backstage_aks_apiserver_url : try("https://${azurerm_kubernetes_cluster.platform[0].private_fqdn}", "")
  )
  backstage_cost_showback_container_url = (
    var.backstage_cost_showback_container_url != "" ? var.backstage_cost_showback_container_url : (
      var.enable_cost_allocator ? try(module.cost_allocator[0].showback_container_url, "") : ""
    )
  )
  backstage_cost_showback_container_id = (
    var.backstage_cost_showback_container_id != "" ? var.backstage_cost_showback_container_id : (
      var.enable_cost_allocator ? try(module.cost_allocator[0].showback_container_id, "") : ""
    )
  )
  backstage_key_vault_secret_names = toset(concat(
    [
      "backstage-session-secret",
      "backstage-microsoft-auth-client-secret",
      "backstage-github-app-id",
      "backstage-github-app-client-id",
      "backstage-github-app-client-secret",
      "backstage-github-app-webhook-secret",
      "backstage-github-app-private-key",
    ],
    var.backstage_postgres_auth_mode == "password" ? ["backstage-postgres-password"] : [],
  ))
  backstage_catalog_reconciler_key_vault_secret_names = toset([
    "backstage-catalog-reconciler-github-token",
    "backstage-catalog-reconciler-teams-webhook-url",
  ])
  backstage_kubernetes_service_account_issuer_url = try(trimsuffix(azurerm_kubernetes_cluster.platform[0].oidc_issuer_url, "/"), "")
  backstage_kubernetes_service_account_jwks_url = (
    local.backstage_kubernetes_service_account_issuer_url != "" ? "${local.backstage_kubernetes_service_account_issuer_url}/openid/v1/jwks" : ""
  )
  backstage_microsoft_graph_group_filter = join(
    " or ",
    [for id in sort(tolist(var.backstage_microsoft_graph_group_object_ids)) : "id eq '${id}'"],
  )
  action_group_name = {
    sev1 = "ag-${local.name_prefix}-sev1"
    sev2 = "ag-${local.name_prefix}-sev2"
    sev3 = "ag-${local.name_prefix}-sev3"
  }
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
    var.enable_techdocs_storage ? { techdocs = ["privatelink.blob.core.windows.net"] } : {},
    var.enable_cost_allocator && !var.cost_allocator_public_network_access_enabled ? { cost_allocator = ["privatelink.blob.core.windows.net", "privatelink.queue.core.windows.net", "privatelink.table.core.windows.net", "privatelink.azurewebsites.net"] } : {},
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
    var.enable_private_endpoints && var.enable_techdocs_storage && contains(keys(var.private_dns_zone_ids), "privatelink.blob.core.windows.net") ? {
      techdocs = {
        resource_id            = azurerm_storage_account.techdocs[0].id
        subresource_names      = ["blob"]
        private_dns_zone_names = ["privatelink.blob.core.windows.net"]
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
    function-integration = {
      name = "app-service"
      service_delegation = {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action",
        ]
      }
    }
  }

  route_table_subnet_keys = concat(
    [
      "aks-system",
      "aks-user",
      "aca-infra",
      "shared-ingress",
    ],
    var.enable_cost_allocator && contains(keys(var.subnet_address_prefixes), "function-integration") ? ["function-integration"] : [],
  )

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
    var.enable_techdocs_storage ? {
      techdocs_blob = "${azurerm_storage_account.techdocs[0].id}/blobServices/default"
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
