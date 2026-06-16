resource "azurerm_container_registry" "platform" {
  #checkov:skip=CKV_AZURE_164:Image signing is enforced with cosign/Kyverno in Stage 06/07; ACR trust policy does not cover the keyless signing model.
  #checkov:skip=CKV_AZURE_166:ACR quarantine can block pull-through cache acceptance; image scan/sign/verify gates are Stage 06/07 supply-chain controls.
  #checkov:skip=CKV_AZURE_167:retention_policy_in_days is set to 14; Checkov does not resolve the current azurerm v4 schema for this resource.
  #checkov:skip=CKV_AZURE_233:Zone redundancy is region/profile dependent; prod enables it when zones are supplied.
  count = var.enable_acr ? 1 : 0

  #checkov:skip=CKV_AZURE_237:CMK for ACR is a later hardening step once platform Key Vault RBAC propagation and key lifecycle are fully wired.
  name                          = local.acr_name
  resource_group_name           = azurerm_resource_group.platform.name
  location                      = azurerm_resource_group.platform.location
  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = false
  retention_policy_in_days      = 14
  export_policy_enabled         = false
  data_endpoint_enabled         = true
  zone_redundancy_enabled       = var.profile == "prod" && length(var.availability_zones) > 1
  # Required for Azure-managed control-plane operations such as az acr import
  # while public network access remains disabled and the registry data plane is
  # reachable only through Private Link.
  network_rule_bypass_option = "AzureServices"

  network_rule_set {
    default_action = "Deny"
  }

  dynamic "georeplications" {
    for_each = toset(local.acr_geo_replication_locations)

    content {
      location                  = georeplications.value
      zone_redundancy_enabled   = var.profile == "prod"
      regional_endpoint_enabled = false
      tags                      = local.tags
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_container_registry_cache_rule" "platform" {
  for_each = var.enable_acr ? var.acr_cache_rules : {}

  name                  = replace(each.key, "_", "")
  container_registry_id = azurerm_container_registry.platform[0].id
  source_repo           = each.value.source_repo
  target_repo           = each.value.target_repo
}

resource "azurerm_role_assignment" "backstage_acr_pull" {
  count = local.backstage_enabled ? 1 : 0

  scope                = azurerm_container_registry.platform[0].id
  role_definition_name = "AcrPull"
  principal_id         = var.backstage_workload_identity_principal_id
  principal_type       = "ServicePrincipal"
}
