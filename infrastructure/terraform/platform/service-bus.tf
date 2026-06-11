resource "azurerm_servicebus_namespace" "platform" {
  #checkov:skip=CKV_AZURE_199:Double encryption requires CMK and Premium-only rollout; tracked as Stage 04 CMK hardening follow-up.
  #checkov:skip=CKV_AZURE_201:CMK requires platform Key Vault key lifecycle and identity grants; tracked as Stage 04 CMK hardening follow-up.
  count = var.enable_service_bus ? 1 : 0

  name                          = local.service_bus_name
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  sku                           = local.service_bus_sku
  capacity                      = local.service_bus_capacity
  premium_messaging_partitions  = local.service_bus_partition
  local_auth_enabled            = false
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = local.tags

  identity {
    type = "SystemAssigned"
  }

  network_rule_set {
    # Service Bus requires Allow when no ip_rules/network_rules are present.
    # public_network_access_enabled=false and the Private Endpoint enforce the
    # private-only posture; rule matching is moot while public access is disabled.
    default_action                = "Allow"
    public_network_access_enabled = false
    trusted_services_allowed      = false
  }
}
