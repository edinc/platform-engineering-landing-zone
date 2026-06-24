output "resource_group_name" {
  value       = azurerm_resource_group.platform.name
  description = "Platform shared-services resource group name."
}

output "platform_virtual_network_id" {
  value       = azurerm_virtual_network.platform.id
  description = "Platform spoke virtual network ID."
}

output "platform_subnet_ids" {
  value       = { for name, subnet in azurerm_subnet.platform : name => subnet.id }
  description = "Platform subnet IDs keyed by subnet name."
}

output "aks_cluster_id" {
  value       = try(azurerm_kubernetes_cluster.platform[0].id, null)
  description = "AKS cluster ID, or null when AKS is disabled."
}

output "aks_oidc_issuer_url" {
  value       = try(azurerm_kubernetes_cluster.platform[0].oidc_issuer_url, null)
  description = "AKS OIDC issuer URL for Stage 07 workload identity federated credentials."
}

output "gitops_flux_extension_id" {
  value       = try(azurerm_kubernetes_cluster_extension.flux[0].id, null)
  description = "Microsoft-managed Flux extension ID, or null when GitOps is disabled."
}

output "gitops_flux_configuration_id" {
  value       = try(azurerm_kubernetes_flux_configuration.platform[0].id, null)
  description = "Root Flux configuration ID, or null when GitOps is disabled."
}

output "backstage_flux_configuration_id" {
  value       = try(azurerm_kubernetes_flux_configuration.backstage[0].id, null)
  description = "Stage 09 Backstage Flux configuration ID, or null when Backstage is disabled."
}

output "platform_workload_identity_client_ids" {
  value = {
    cert_manager                 = local.cert_manager_workload_identity_client_id
    external_dns                 = local.external_dns_workload_identity_client_id
    external_secrets             = local.external_secrets_workload_identity_client_id
    aso                          = local.aso_workload_identity_client_id
    flux_source                  = local.flux_source_workload_identity_client_id
    backstage                    = local.backstage_workload_identity_client_id
    backstage_catalog_reconciler = local.backstage_catalog_reconciler_workload_identity_client_id
  }
  description = "Effective Workload Identity client IDs for platform add-ons and Backstage. Values come from variables when supplied, otherwise from Terraform-created managed identities."
}

output "platform_workload_identity_principal_ids" {
  value = {
    flux_source                  = local.flux_source_workload_identity_principal_id
    backstage                    = local.backstage_workload_identity_principal_id
    backstage_catalog_reconciler = local.backstage_catalog_reconciler_workload_identity_principal_id
  }
  description = "Effective principal IDs for platform identities that receive Azure RBAC assignments."
}

output "gitops_cluster_state_root_path" {
  value       = local.gitops_root_path
  description = "platform-cluster-state path reconciled by the root Flux Kustomization."
}

output "acr_id" {
  value       = try(azurerm_container_registry.platform[0].id, null)
  description = "Azure Container Registry ID, or null when disabled."
}

output "acr_login_server" {
  value       = try(azurerm_container_registry.platform[0].login_server, null)
  description = "ACR login server, or null when disabled."
}

output "key_vault_id" {
  value       = try(azurerm_key_vault.platform[0].id, null)
  description = "Platform Key Vault ID, or null when disabled."
}

output "postgres_server_id" {
  value       = try(azurerm_postgresql_flexible_server.platform[0].id, null)
  description = "PostgreSQL Flexible Server ID, or null when disabled."
}

output "service_bus_namespace_id" {
  value       = try(azurerm_servicebus_namespace.platform[0].id, null)
  description = "Service Bus namespace ID, or null when disabled."
}

output "aca_environment_id" {
  value       = try(azurerm_container_app_environment.platform[0].id, null)
  description = "Container Apps managed environment ID, or null when disabled."
}

output "front_door_profile_id" {
  value       = try(azurerm_cdn_frontdoor_profile.platform[0].id, null)
  description = "Front Door Premium profile ID, or null when disabled."
}

output "backstage_public_ingress_ip_address" {
  value       = try(azurerm_public_ip.backstage_public_ingress[0].ip_address, null)
  description = "Static public IP address for the dedicated public Backstage ingress, or null when disabled."
}

output "backstage_public_ingress_fqdn" {
  value       = try(azurerm_public_ip.backstage_public_ingress[0].fqdn, null)
  description = "Azure cloudapp FQDN for the dedicated public Backstage ingress, or null when disabled."
}

output "backstage_microsoft_auth_redirect_uri" {
  value       = local.backstage_enabled ? "https://${local.backstage_microsoft_auth_redirect_uri}" : null
  description = "Redirect URI that must be configured on the Backstage Microsoft Entra app registration."
}

output "aks_node_auto_provisioning_enabled" {
  value       = var.enable_aks && var.enable_aks_node_auto_provisioning
  description = "Whether Stage 08 AKS Node Auto-Provisioning is enabled for the platform cluster."
}

output "stage08_action_group_ids" {
  value       = { for severity, action_group in azurerm_monitor_action_group.stage08 : severity => action_group.id }
  description = "Azure Monitor Action Group IDs keyed by severity for Stage 08 alert routing."
}

output "stage08_prometheus_rule_group_id" {
  value       = try(azurerm_monitor_alert_prometheus_rule_group.platform_slos[0].id, null)
  description = "Managed Prometheus alert rule group ID for Stage 08 platform SLO alerts, or null when alerting is disabled."
}

output "cost_allocator_function_app_id" {
  value       = try(module.cost_allocator[0].function_app_id, null)
  description = "Stage 08 cost allocator Function App ID, or null when disabled."
}

output "cost_allocator_showback_container_id" {
  value       = try(module.cost_allocator[0].showback_container_id, null)
  description = "Stage 08 cost showback output container ID, or null when disabled."
}

output "techdocs_storage_account_name" {
  value       = try(azurerm_storage_account.techdocs[0].name, null)
  description = "Stage 09 TechDocs storage account name, or null when disabled."
}

output "techdocs_storage_container_id" {
  value       = try(azurerm_storage_container.techdocs[0].id, null)
  description = "Stage 09 TechDocs Blob container resource ID, or null when disabled."
}

output "private_endpoint_ids" {
  value       = { for key, endpoint in azurerm_private_endpoint.platform : key => endpoint.id }
  description = "Private Endpoint IDs keyed by service."
}

output "backend_config_hint" {
  value = {
    container_name   = "platform"
    key              = "${var.profile}/platform.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
