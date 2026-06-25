locals {
  gitops_enabled    = var.enable_aks && var.enable_gitops
  backstage_enabled = local.gitops_enabled && var.enable_backstage
  gitops_repository_url = (
    var.cluster_state_repository_url != "" ? var.cluster_state_repository_url : "https://github.com/${var.github_owner}/platform-cluster-state"
  )
  gitops_root_path = (
    var.cluster_state_root_path != "" ? var.cluster_state_root_path : "clusters/overlays/${var.profile}"
  )
}

resource "terraform_data" "flux_extension_recreate_epoch" {
  input = var.recreate_flux_extension_epoch
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  count = local.gitops_enabled ? 1 : 0

  name              = "flux"
  cluster_id        = azurerm_kubernetes_cluster.platform[0].id
  extension_type    = "microsoft.flux"
  release_train     = "Stable"
  release_namespace = var.gitops_flux_namespace
  configuration_settings = {
    "multiTenancy.enforce"                          = "true"
    "kustomize-controller.strict-substitution-mode" = "true"
    "helm-controller.detectDrift"                   = "true"
    "workloadIdentity.enable"                       = "true"
    "workloadIdentity.azureClientId"                = local.flux_source_workload_identity_client_id
    "workloadIdentity.azureTenantId"                = var.tenant_id
  }

  lifecycle {
    replace_triggered_by = [
      terraform_data.flux_extension_recreate_epoch,
    ]
  }
}

resource "azurerm_kubernetes_flux_configuration" "platform" {
  count = local.gitops_enabled ? 1 : 0

  name                              = "platform-${var.profile}"
  cluster_id                        = azurerm_kubernetes_cluster.platform[0].id
  namespace                         = var.gitops_flux_namespace
  scope                             = "cluster"
  continuous_reconciliation_enabled = true

  git_repository {
    url                      = local.gitops_repository_url
    reference_type           = "branch"
    reference_value          = var.cluster_state_branch
    provider                 = var.gitops_repository_provider == "" ? null : var.gitops_repository_provider
    ssh_private_key_base64   = var.cluster_state_ssh_private_key_base64 == "" ? null : var.cluster_state_ssh_private_key_base64
    ssh_known_hosts_base64   = var.cluster_state_ssh_known_hosts_base64 == "" ? null : var.cluster_state_ssh_known_hosts_base64
    sync_interval_in_seconds = var.gitops_sync_interval_seconds
    timeout_in_seconds       = var.gitops_timeout_seconds
  }

  kustomizations {
    name                       = "cluster-${var.profile}"
    path                       = local.gitops_root_path
    garbage_collection_enabled = true
    retry_interval_in_seconds  = var.gitops_sync_interval_seconds
    sync_interval_in_seconds   = var.gitops_sync_interval_seconds
    timeout_in_seconds         = var.gitops_timeout_seconds
    wait                       = true

    post_build {
      substitute = {
        application_insights_ingestion_endpoint = var.application_insights_ingestion_endpoint
        aks_kubelet_client_id                   = try(azurerm_kubernetes_cluster.platform[0].kubelet_identity[0].client_id, "")
        aso_client_id                           = local.aso_workload_identity_client_id
        azure_dns_resource_group_name           = var.azure_dns_resource_group_name
        backstage_public_ingress_controller_replicas = (
          local.backstage_public_ingress_enabled ? jsonencode("1") : jsonencode("0")
        )
        backstage_public_ingress_enabled        = jsonencode(tostring(local.backstage_public_ingress_enabled))
        backstage_public_ingress_host           = jsonencode(local.backstage_public_ingress_host)
        backstage_public_ingress_public_ip_name = jsonencode(try(azurerm_public_ip.backstage_public_ingress[0].name, ""))
        backstage_public_ingress_resource_group = jsonencode(azurerm_resource_group.platform.name)
        cert_manager_client_id                  = local.cert_manager_workload_identity_client_id
        cluster_state_branch                    = var.cluster_state_branch
        cluster_state_repository_provider       = var.gitops_repository_provider == "" ? "generic" : lower(var.gitops_repository_provider)
        cluster_state_repository_url            = local.gitops_repository_url
        cluster_state_root_path                 = local.gitops_root_path
        external_dns_client_id                  = local.external_dns_workload_identity_client_id
        external_secrets_client_id              = local.external_secrets_workload_identity_client_id
        github_owner                            = var.github_owner
        platform_acr_login_server               = try(azurerm_container_registry.platform[0].login_server, "")
        platform_key_vault_name                 = local.key_vault_name
        platform_profile                        = var.profile
        platform_repository_name                = var.github_repo
        platform_root_domain                    = var.platform_root_domain
        platform_subscription_id                = var.subscription_id
        platform_tenant_id                      = var.tenant_id
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.flux,
    azurerm_federated_identity_credential.platform_workload,
    azurerm_role_assignment.flux_source_acr_pull,
    azurerm_role_assignment.aso_platform_operator,
    azurerm_role_assignment.cert_manager_dns,
    azurerm_role_assignment.cert_manager_key_vault_secret_user,
    azurerm_role_assignment.external_dns,
    azurerm_role_assignment.external_secrets_key_vault_secret_user,
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.flux_extension_recreate_epoch,
    ]
  }
}

resource "azurerm_kubernetes_flux_configuration" "backstage" {
  count = local.backstage_enabled ? 1 : 0

  name                              = "backstage-${var.profile}"
  cluster_id                        = azurerm_kubernetes_cluster.platform[0].id
  namespace                         = var.gitops_flux_namespace
  scope                             = "cluster"
  continuous_reconciliation_enabled = true

  git_repository {
    url                      = local.gitops_repository_url
    reference_type           = "branch"
    reference_value          = var.cluster_state_branch
    provider                 = var.gitops_repository_provider == "" ? null : var.gitops_repository_provider
    ssh_private_key_base64   = var.cluster_state_ssh_private_key_base64 == "" ? null : var.cluster_state_ssh_private_key_base64
    ssh_known_hosts_base64   = var.cluster_state_ssh_known_hosts_base64 == "" ? null : var.cluster_state_ssh_known_hosts_base64
    sync_interval_in_seconds = var.gitops_sync_interval_seconds
    timeout_in_seconds       = var.gitops_timeout_seconds
  }

  kustomizations {
    name                       = "backstage-${var.profile}"
    path                       = "${local.gitops_root_path}/backstage"
    garbage_collection_enabled = true
    retry_interval_in_seconds  = var.gitops_sync_interval_seconds
    sync_interval_in_seconds   = var.gitops_sync_interval_seconds
    timeout_in_seconds         = var.gitops_timeout_seconds
    wait                       = true

    post_build {
      substitute = {
        backstage_aks_apiserver_url                     = local.backstage_aks_apiserver_url
        backstage_application_team_group_map_json       = var.backstage_application_team_group_map_json
        backstage_application_team_group_refs           = var.backstage_application_team_group_refs
        backstage_catalog_reconciler_client_id          = local.backstage_catalog_reconciler_workload_identity_client_id
        backstage_catalog_reconciler_image_digest       = var.backstage_catalog_reconciler_image_digest
        backstage_catalog_reconciler_image_repository   = local.backstage_catalog_reconciler_image_repository
        backstage_chart_digest                          = var.backstage_chart_digest
        backstage_chart_version                         = var.backstage_chart_version
        backstage_cost_showback_url                     = local.backstage_cost_showback_container_url
        backstage_client_id                             = local.backstage_workload_identity_client_id
        backstage_public_ingress_host                   = local.backstage_public_ingress_host
        backstage_image_digest                          = var.backstage_image_digest
        backstage_image_repository                      = local.backstage_image_repository
        backstage_microsoft_auth_client_id              = var.backstage_microsoft_auth_client_id
        backstage_microsoft_graph_group_filter          = local.backstage_microsoft_graph_group_filter
        backstage_kubernetes_service_account_issuer_url = local.backstage_kubernetes_service_account_issuer_url
        backstage_kubernetes_service_account_jwks_url   = local.backstage_kubernetes_service_account_jwks_url
        backstage_postgres_auth_mode                    = var.backstage_postgres_auth_mode
        backstage_postgres_host                         = local.backstage_postgres_host
        backstage_postgres_user                         = local.backstage_postgres_user
        github_owner                                    = var.github_owner
        platform_acr_login_server                       = try(azurerm_container_registry.platform[0].login_server, "")
        platform_key_vault_name                         = local.key_vault_name
        platform_profile                                = var.profile
        platform_repository_name                        = var.github_repo
        platform_repository_url                         = "github.com?owner=${var.github_owner}&repo=${var.github_repo}"
        platform_root_domain                            = var.platform_root_domain
        platform_subscription_id                        = var.subscription_id
        platform_tenant_id                              = var.tenant_id
        techdocs_storage_account_name                   = azurerm_storage_account.techdocs[0].name
        techdocs_storage_container_name                 = local.techdocs_container_name
      }
    }
  }

  depends_on = [
    azurerm_federated_identity_credential.platform_workload,
    azurerm_kubernetes_flux_configuration.platform,
    azurerm_role_assignment.flux_source_acr_pull,
    azurerm_role_assignment.backstage_aks_cluster_user,
    azurerm_role_assignment.backstage_aks_rbac_reader,
    azurerm_role_assignment.backstage_cost_showback_reader,
    azurerm_role_assignment.backstage_key_vault_secret_user,
    azurerm_role_assignment.backstage_catalog_reconciler_key_vault_secret_user,
    azurerm_role_assignment.techdocs_backstage_writer,
    azurerm_role_assignment.techdocs_publisher_writer,
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.flux_extension_recreate_epoch,
    ]
  }
}
