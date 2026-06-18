resource "terraform_data" "input_guard" {
  input = {
    enable_aks                        = var.enable_aks
    enable_acr                        = var.enable_acr
    enable_key_vault                  = var.enable_key_vault
    enable_postgres                   = var.enable_postgres
    enable_service_bus                = var.enable_service_bus
    enable_private_endpoints          = var.enable_private_endpoints
    log_analytics_workspace_id        = var.log_analytics_workspace_id
    private_dns_zone_ids              = var.private_dns_zone_ids
    postgres_password_is_present      = var.postgres_administrator_password != null
    enable_alerting_action_groups     = var.enable_alerting_action_groups
    enable_aks_node_auto_provisioning = var.enable_aks_node_auto_provisioning
    enable_cost_allocator             = var.enable_cost_allocator
  }

  lifecycle {
    precondition {
      condition     = length(local.acr_name) <= 50
      error_message = "The derived ACR name exceeds Azure's 50-character limit; shorten name_suffix, profile, or location_short."
    }

    precondition {
      condition     = length(local.key_vault_name) <= 24
      error_message = "The derived Key Vault name exceeds Azure's 24-character limit; shorten name_suffix, profile, or location_short."
    }

    precondition {
      condition     = length(local.service_bus_name) <= 50
      error_message = "The derived Service Bus namespace name exceeds Azure's 50-character limit; shorten name_suffix, profile, or location_short."
    }

    precondition {
      condition     = length(local.techdocs_storage_name) <= 24
      error_message = "The derived TechDocs storage account name exceeds Azure's 24-character limit; shorten name_suffix, profile, or location_short."
    }

    precondition {
      condition     = length(local.postgres_name) <= 63
      error_message = "The derived PostgreSQL Flexible Server name exceeds Azure's 63-character limit; shorten name_suffix, profile, or location_short."
    }

    precondition {
      condition     = !var.enable_aks_defender || var.log_analytics_workspace_id != ""
      error_message = "enable_aks_defender requires log_analytics_workspace_id."
    }

    precondition {
      condition     = !var.enable_aks || var.profile == "demo" || var.firewall_private_ip_address != ""
      error_message = "enable_aks requires firewall_private_ip_address for non-demo profiles so AKS egress uses Stage 03 user-defined routing."
    }

    precondition {
      condition     = !var.enable_gitops || var.enable_aks
      error_message = "enable_gitops requires enable_aks."
    }

    precondition {
      condition     = !var.enable_gitops || var.enable_key_vault
      error_message = "enable_gitops requires enable_key_vault because Stage 07 cert-manager and CSI integrations use the platform Key Vault."
    }

    precondition {
      condition = (
        !var.enable_gitops ||
        alltrue([
          var.platform_root_domain != "",
          var.azure_dns_resource_group_name != "",
          var.application_insights_ingestion_endpoint != "",
        ])
      )
      error_message = "enable_gitops requires platform_root_domain, azure_dns_resource_group_name, and application_insights_ingestion_endpoint. Platform Workload Identity client IDs are optional overrides; Terraform creates managed identities and federated credentials when they are omitted."
    }

    precondition {
      condition = (
        var.backstage_workload_identity_client_id == "" &&
        var.backstage_workload_identity_principal_id == "" ||
        var.backstage_workload_identity_client_id != "" &&
        var.backstage_workload_identity_principal_id != ""
      )
      error_message = "Brownfield Backstage Workload Identity adoption requires both backstage_workload_identity_client_id and backstage_workload_identity_principal_id, or neither so Terraform can create the identity."
    }

    precondition {
      condition = (
        var.backstage_catalog_reconciler_workload_identity_client_id == "" &&
        var.backstage_catalog_reconciler_workload_identity_principal_id == "" ||
        var.backstage_catalog_reconciler_workload_identity_client_id != "" &&
        var.backstage_catalog_reconciler_workload_identity_principal_id != ""
      )
      error_message = "Brownfield Backstage catalog reconciler Workload Identity adoption requires both backstage_catalog_reconciler_workload_identity_client_id and backstage_catalog_reconciler_workload_identity_principal_id, or neither so Terraform can create the identity."
    }

    precondition {
      condition     = !var.enable_backstage || var.enable_gitops
      error_message = "enable_backstage requires enable_gitops so Flux owns the Backstage deployment."
    }

    precondition {
      condition = (
        !var.enable_backstage ||
        alltrue([
          var.enable_acr,
          var.enable_techdocs_storage,
          var.platform_root_domain != "",
          length(var.backstage_microsoft_graph_group_object_ids) > 0,
          var.backstage_microsoft_auth_client_id != "",
          var.backstage_chart_digest != "",
          var.backstage_image_digest != "",
          var.backstage_catalog_reconciler_image_digest != "",
          try(azurerm_container_registry.platform[0].login_server, "") != "",
          local.backstage_image_repository != "",
          local.backstage_catalog_reconciler_image_repository != "",
          local.backstage_postgres_host != "",
          local.backstage_aks_apiserver_url != "",
          local.backstage_kubernetes_service_account_issuer_url != "",
          local.backstage_kubernetes_service_account_jwks_url != "",
        ])
      )
      error_message = "enable_backstage requires enable_acr, enable_techdocs_storage, platform_root_domain, backstage_microsoft_graph_group_object_ids, backstage_microsoft_auth_client_id, backstage_chart_digest, backstage_image_digest, backstage_catalog_reconciler_image_digest, Backstage image repositories, Backstage Postgres host, and AKS API server/OIDC issuer URL. Workload Identity IDs are optional overrides; Terraform creates managed identities and federated credentials when they are omitted."
    }

    precondition {
      condition     = !var.enable_gitops || can(regex("^clusters/overlays/${var.profile}$", local.gitops_root_path))
      error_message = "enable_gitops requires the Flux root path to match clusters/overlays/<profile>."
    }

    precondition {
      condition     = !var.enable_aks_node_auto_provisioning || var.enable_aks
      error_message = "enable_aks_node_auto_provisioning requires enable_aks."
    }

    precondition {
      condition = (
        !var.enable_alerting_action_groups ||
        (var.profile == "demo" && var.alerting_teams_webhook_url != "") ||
        (var.profile != "demo" && var.alerting_pagerduty_itsm != null)
      )
      error_message = "enable_alerting_action_groups requires alerting_teams_webhook_url for demo and alerting_pagerduty_itsm for nonprod/prod."
    }

    precondition {
      condition     = !var.enable_alerting_action_groups || var.azure_monitor_workspace_id != ""
      error_message = "enable_alerting_action_groups requires azure_monitor_workspace_id so Managed Prometheus rules can route to Action Groups."
    }

    precondition {
      condition     = !var.enable_alerting_action_groups || var.enable_managed_prometheus
      error_message = "enable_alerting_action_groups requires enable_managed_prometheus so platform SLO rules have a metrics source."
    }

    precondition {
      condition     = !var.enable_cost_allocator || var.cost_export_storage_container_id != ""
      error_message = "enable_cost_allocator requires cost_export_storage_container_id."
    }

    precondition {
      condition     = !var.enable_cost_allocator || var.cost_allocator_function_package_path != null
      error_message = "enable_cost_allocator requires cost_allocator_function_package_path pointing at the packaged Function App."
    }

    precondition {
      condition = (
        !var.enable_cost_allocator ||
        var.cost_allocator_public_network_access_enabled ||
        contains(keys(var.private_dns_zone_ids), "privatelink.blob.core.windows.net") &&
        contains(keys(var.private_dns_zone_ids), "privatelink.queue.core.windows.net") &&
        contains(keys(var.private_dns_zone_ids), "privatelink.table.core.windows.net") &&
        contains(keys(var.private_dns_zone_ids), "privatelink.azurewebsites.net")
      )
      error_message = "enable_cost_allocator with public access disabled requires private DNS zones for blob, queue, table, and azurewebsites private endpoints."
    }

    precondition {
      condition     = !var.enable_aca_environment || var.profile == "demo" || var.firewall_private_ip_address != ""
      error_message = "enable_aca_environment requires firewall_private_ip_address for non-demo profiles so the internal ACA environment has an explicit outbound path."
    }

    precondition {
      condition     = !var.enable_postgres || var.postgres_administrator_password != null
      error_message = "enable_postgres requires postgres_administrator_password supplied out of band."
    }

    precondition {
      condition     = !var.enable_postgres || contains(keys(var.private_dns_zone_ids), local.postgres_private_dns_zone_name)
      error_message = "enable_postgres requires private_dns_zone_ids to include privatelink.postgres.database.azure.com."
    }

    precondition {
      condition     = !var.enable_techdocs_storage || local.backstage_enabled || var.backstage_workload_identity_principal_id != ""
      error_message = "enable_techdocs_storage requires enable_backstage or backstage_workload_identity_principal_id for Azure Blob data-plane RBAC."
    }

    precondition {
      condition     = !var.enable_techdocs_storage || contains(keys(var.private_dns_zone_ids), "privatelink.blob.core.windows.net")
      error_message = "enable_techdocs_storage requires private_dns_zone_ids to include privatelink.blob.core.windows.net."
    }

    precondition {
      condition     = !var.enable_techdocs_storage || var.enable_private_endpoints
      error_message = "enable_techdocs_storage requires enable_private_endpoints because TechDocs storage disables public network access."
    }

    precondition {
      condition = (
        !var.enable_private_endpoints ||
        alltrue(flatten([
          for zones in values(local.private_endpoint_required_zones) : [
            for zone_name in zones : contains(keys(var.private_dns_zone_ids), zone_name)
          ]
        ]))
      )
      error_message = "enable_private_endpoints requires private_dns_zone_ids for every enabled PaaS resource."
    }
  }
}

resource "azurerm_resource_group" "platform" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}
