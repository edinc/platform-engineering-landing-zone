resource "azurerm_key_vault" "platform" {
  #checkov:skip=CKV2_AZURE_32:Private Endpoint is created by azurerm_private_endpoint.platform when Stage 03 Private DNS zone IDs are supplied; Checkov cannot trace the conditional map.
  count = var.enable_key_vault ? 1 : 0

  name                            = local.key_vault_name
  location                        = azurerm_resource_group.platform.location
  resource_group_name             = azurerm_resource_group.platform.name
  tenant_id                       = var.tenant_id
  sku_name                        = var.key_vault_sku
  rbac_authorization_enabled      = true
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90
  public_network_access_enabled   = false
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false

  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }

  tags = local.tags
}
