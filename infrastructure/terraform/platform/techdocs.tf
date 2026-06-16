resource "azurerm_storage_account" "techdocs" {
  count = var.enable_techdocs_storage ? 1 : 0

  #checkov:skip=CKV_AZURE_43:local.techdocs_storage_name is lower-case alphanumeric and length-guarded by terraform_data.input_guard.
  #checkov:skip=CKV2_AZURE_1:CMK is deferred until the platform Key Vault key lifecycle is introduced for all storage workloads.
  name                = local.techdocs_storage_name
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  account_tier             = "Standard"
  account_replication_type = var.profile == "demo" ? "LRS" : "ZRS"
  account_kind             = "StorageV2"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = false

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = merge(local.tags, {
    product = "backstage"
  })
}

resource "azurerm_storage_container" "techdocs" {
  count = var.enable_techdocs_storage ? 1 : 0

  #checkov:skip=CKV2_AZURE_21:Blob read/write/delete is logged through the platform diagnostic target map at blobServices/default.
  name                  = local.techdocs_container_name
  storage_account_id    = azurerm_storage_account.techdocs[0].id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "techdocs_backstage_writer" {
  count = var.enable_techdocs_storage ? 1 : 0

  scope                = "${azurerm_storage_account.techdocs[0].id}/blobServices/default/containers/${azurerm_storage_container.techdocs[0].name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.backstage_workload_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "techdocs_publisher_writer" {
  for_each = var.enable_techdocs_storage ? var.techdocs_publisher_principal_ids : toset([])

  scope                = "${azurerm_storage_account.techdocs[0].id}/blobServices/default/containers/${azurerm_storage_container.techdocs[0].name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
