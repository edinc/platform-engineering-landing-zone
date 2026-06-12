resource "terraform_data" "input_guard" {
  input = {
    enable_aks                   = var.enable_aks
    enable_acr                   = var.enable_acr
    enable_key_vault             = var.enable_key_vault
    enable_postgres              = var.enable_postgres
    enable_service_bus           = var.enable_service_bus
    enable_private_endpoints     = var.enable_private_endpoints
    log_analytics_workspace_id   = var.log_analytics_workspace_id
    private_dns_zone_ids         = var.private_dns_zone_ids
    postgres_password_is_present = var.postgres_administrator_password != null
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
          var.cert_manager_workload_identity_client_id != "",
          var.external_dns_workload_identity_client_id != "",
          var.external_secrets_workload_identity_client_id != "",
          var.aso_workload_identity_client_id != "",
          var.application_insights_ingestion_endpoint != "",
        ])
      )
      error_message = "enable_gitops requires platform_root_domain, azure_dns_resource_group_name, cert_manager_workload_identity_client_id, external_dns_workload_identity_client_id, external_secrets_workload_identity_client_id, aso_workload_identity_client_id, and application_insights_ingestion_endpoint."
    }

    precondition {
      condition     = !var.enable_gitops || can(regex("^clusters/overlays/${var.profile}$", local.gitops_root_path))
      error_message = "enable_gitops requires the Flux root path to match clusters/overlays/<profile>."
    }

    precondition {
      condition     = !var.enable_aca_environment || var.firewall_private_ip_address != ""
      error_message = "enable_aca_environment requires firewall_private_ip_address so the internal ACA environment has an explicit outbound path."
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
