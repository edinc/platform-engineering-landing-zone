resource "terraform_data" "input_guard" {
  input = {
    public_network_access_enabled = var.public_network_access_enabled
    private_endpoint_subnet_id    = var.private_endpoint_subnet_id
    virtual_network_subnet_id     = var.virtual_network_subnet_id
    private_dns_zone_ids          = var.private_dns_zone_ids
  }

  lifecycle {
    precondition {
      condition = (
        var.public_network_access_enabled ||
        var.private_endpoint_subnet_id != "" &&
        var.virtual_network_subnet_id != "" &&
        alltrue([
          for zone_name in values(local.private_endpoint_zone_names) : contains(keys(var.private_dns_zone_ids), zone_name)
        ]) &&
        contains(keys(var.private_dns_zone_ids), local.function_private_endpoint_zone_name)
      )
      error_message = "Private cost allocator deployment requires virtual_network_subnet_id, private_endpoint_subnet_id, and private_dns_zone_ids for blob, queue, table, and azurewebsites."
    }
  }
}

resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_33:Queue service is required by Azure Functions host storage.
  #checkov:skip=CKV_AZURE_43:local.storage_account_name strips hyphens, lowercases, truncates to 24 chars, and storage_account_name validates Azure naming rules.
  #checkov:skip=CKV_AZURE_206:storage_replication_type defaults to ZRS; the module keeps replication configurable for paired-region/data-residency profiles.
  #checkov:skip=CKV2_AZURE_1:Cost showback storage contains derived internal CSVs; CMK can be applied by the consuming platform stack when the key lifecycle is available.
  #checkov:skip=CKV2_AZURE_33:Private Endpoints are wired by the consuming platform stack when public_network_access_enabled is set false.
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = var.public_network_access_enabled

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

  tags = var.tags
}

resource "azurerm_storage_container" "showback" {
  #checkov:skip=CKV2_AZURE_21:Diagnostic settings are applied by the consuming platform stack using the module output storage_account_id.
  name                  = var.showback_container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "this" {
  name                   = "asp-${var.name_prefix}-cost"
  resource_group_name    = var.resource_group_name
  location               = var.location
  os_type                = "Linux"
  sku_name               = var.service_plan_sku_name
  worker_count           = var.service_plan_worker_count
  zone_balancing_enabled = var.service_plan_zone_balancing_enabled
  tags                   = var.tags
}

resource "azurerm_linux_function_app" "this" {
  name                = local.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id               = azurerm_service_plan.this.id
  storage_account_name          = azurerm_storage_account.this.name
  storage_uses_managed_identity = true
  virtual_network_subnet_id     = var.virtual_network_subnet_id == "" ? null : var.virtual_network_subnet_id
  functions_extension_version   = "~4"
  https_only                    = true
  public_network_access_enabled = var.public_network_access_enabled
  zip_deploy_file               = var.function_package_path
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                              = var.service_plan_sku_name != "Y1"
    application_insights_connection_string = var.application_insights_connection_string == "" ? null : var.application_insights_connection_string
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.2"

    application_stack {
      python_version = var.python_version
    }
  }

  app_settings = merge(
    {
      COST_ALLOCATOR_SCHEDULE            = var.schedule
      COST_EXPORT_ACCOUNT_URL            = "https://${local.source_storage_account_name}.blob.core.windows.net"
      COST_EXPORT_CONTAINER              = local.source_container_name
      COST_EXPORT_ROOT_FOLDER            = var.cost_export_root_folder
      COST_SHOWBACK_ACCOUNT_URL          = "https://${azurerm_storage_account.this.name}.blob.core.windows.net"
      COST_SHOWBACK_CONTAINER            = azurerm_storage_container.showback.name
      FUNCTIONS_WORKER_RUNTIME           = "python"
      SCM_DO_BUILD_DURING_DEPLOYMENT     = var.function_package_path == null ? "false" : "true"
      cost_allocator_required_tag_fields = "costCenter,team,product"
    },
    var.app_settings,
  )
}

resource "azurerm_private_endpoint" "storage" {
  for_each = local.private_endpoint_specs

  name                = "pe-${var.name_prefix}-cost-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name_prefix}-cost-${each.key}"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids[each.value]]
  }
}

resource "azurerm_private_endpoint" "function_app" {
  count = local.function_private_endpoint_enabled ? 1 : 0

  name                = "pe-${var.name_prefix}-cost-func"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name_prefix}-cost-func"
    private_connection_resource_id = azurerm_linux_function_app.this.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids[local.function_private_endpoint_zone_name]]
  }
}

resource "azurerm_role_assignment" "source_cost_reader" {
  scope                = var.cost_export_storage_container_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "showback_writer" {
  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.showback.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "host_blob_owner" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "host_queue_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "host_table_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_linux_function_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
