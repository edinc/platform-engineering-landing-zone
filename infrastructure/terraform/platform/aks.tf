resource "azurerm_user_assigned_identity" "aks" {
  count = var.enable_aks ? 1 : 0

  name                = "id-${local.name_prefix}-aks"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "aks_private_dns" {
  provider = azurerm.dns
  count = (
    var.enable_aks && contains(keys(var.private_dns_zone_ids), local.aks_private_dns_zone_name)
  ) ? 1 : 0

  scope                = var.private_dns_zone_ids[local.aks_private_dns_zone_name]
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_network" {
  count = var.enable_aks ? 1 : 0

  scope                = azurerm_virtual_network.platform.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "platform" {
  #checkov:skip=CKV_AZURE_116:Azure Policy add-on installs Gatekeeper; Kyverno is the single in-cluster admission engine per ADR-0036.
  #checkov:skip=CKV_AZURE_117:AKS disk encryption set is a Stage 04 hardening follow-up once CMK lifecycle is fully wired.
  #checkov:skip=CKV_AZURE_171:automatic_upgrade_channel is set to stable; Checkov does not resolve this provider argument.
  #checkov:skip=CKV_AZURE_227:host_encryption_enabled is set on every node pool; Checkov does not resolve nested/default node pool settings in this azurerm schema.
  count = var.enable_aks ? 1 : 0

  name                              = "aks-${local.name_prefix}"
  location                          = azurerm_resource_group.platform.location
  resource_group_name               = azurerm_resource_group.platform.name
  dns_prefix_private_cluster        = "aks-${local.name_prefix}"
  kubernetes_version                = var.kubernetes_version
  sku_tier                          = "Standard"
  private_cluster_enabled           = true
  private_dns_zone_id               = lookup(var.private_dns_zone_ids, local.aks_private_dns_zone_name, "System")
  role_based_access_control_enabled = true
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  automatic_upgrade_channel         = "stable"
  node_os_upgrade_channel           = "NodeImage"
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48
  azure_policy_enabled              = false
  tags                              = local.tags

  default_node_pool {
    name                         = "system"
    vm_size                      = var.aks_system_node_pool.vm_size
    node_count                   = var.aks_system_node_pool.node_count
    vnet_subnet_id               = azurerm_subnet.platform["aks-system"].id
    zones                        = var.availability_zones
    only_critical_addons_enabled = true
    host_encryption_enabled      = var.aks_host_encryption_enabled
    max_pods                     = 110
    os_disk_type                 = "Ephemeral"
    os_sku                       = "AzureLinux"
    temporary_name_for_rotation  = "syspooltmp"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks[0].id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    azure_rbac_enabled     = true
    admin_group_object_ids = var.aks_admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = local.route_table_enabled ? "userDefinedRouting" : "loadBalancer"
    service_cidr        = var.aks_service_cidr
    dns_service_ip      = var.aks_dns_service_ip
    pod_cidr            = var.aks_pod_cidr
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "10m"
  }

  dynamic "microsoft_defender" {
    for_each = var.enable_aks_defender ? [var.log_analytics_workspace_id] : []

    content {
      log_analytics_workspace_id = microsoft_defender.value
    }
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != "" ? [var.log_analytics_workspace_id] : []

    content {
      log_analytics_workspace_id = oms_agent.value
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.enable_managed_prometheus ? [1] : []

    content {
      annotations_allowed = null
      labels_allowed      = null
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  depends_on = [
    azurerm_role_assignment.aks_network,
    azurerm_role_assignment.aks_private_dns,
    azurerm_subnet_route_table_association.egress,
  ]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "default_user" {
  #checkov:skip=CKV_AZURE_227:host_encryption_enabled is controlled by aks_host_encryption_enabled; default true, demo can opt out when the subscription lacks EncryptionAtHost.
  count = var.enable_aks ? 1 : 0

  name                        = "user"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.platform[0].id
  vm_size                     = var.aks_user_node_pool.vm_size
  mode                        = "User"
  vnet_subnet_id              = azurerm_subnet.platform["aks-user"].id
  auto_scaling_enabled        = true
  host_encryption_enabled     = var.aks_host_encryption_enabled
  max_pods                    = 110
  min_count                   = var.aks_user_node_pool.min_count
  max_count                   = var.aks_user_node_pool.max_count
  node_count                  = var.aks_user_node_pool.min_count
  os_disk_type                = "Ephemeral"
  os_sku                      = "AzureLinux"
  orchestrator_version        = var.kubernetes_version
  zones                       = var.availability_zones
  temporary_name_for_rotation = "userpooltmp"
  tags                        = local.tags

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [
      node_count,
      tags,
    ]
  }
}

resource "azapi_update_resource" "aks_node_auto_provisioning" {
  count = var.enable_aks && var.enable_aks_node_auto_provisioning ? 1 : 0

  type        = "Microsoft.ContainerService/managedClusters@2025-05-01"
  resource_id = azurerm_kubernetes_cluster.platform[0].id

  body = {
    properties = {
      nodeProvisioningProfile = {
        mode = "Auto"
      }
    }
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  count = var.enable_aks && var.enable_acr ? 1 : 0

  scope                            = azurerm_container_registry.platform[0].id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.platform[0].kubelet_identity[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
