locals {
  source_match = regex(
    "^/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/([^/]+)/providers/Microsoft\\.Storage/storageAccounts/([^/]+)/blobServices/default/containers/([^/]+)$",
    var.cost_export_storage_container_id,
  )

  source_storage_account_name = local.source_match[2]
  source_container_name       = local.source_match[3]
  storage_account_name = (
    var.storage_account_name != "" ? var.storage_account_name : substr(replace(lower("st${var.name_prefix}cost"), "-", ""), 0, 24)
  )
  function_app_name = substr("func-${var.name_prefix}-cost", 0, 60)
  private_endpoint_zone_names = {
    blob  = "privatelink.blob.core.windows.net"
    queue = "privatelink.queue.core.windows.net"
    table = "privatelink.table.core.windows.net"
  }
  function_private_endpoint_zone_name = "privatelink.azurewebsites.net"
  private_endpoint_specs              = var.public_network_access_enabled || var.private_endpoint_subnet_id == "" ? {} : local.private_endpoint_zone_names
  function_private_endpoint_enabled   = !var.public_network_access_enabled && var.private_endpoint_subnet_id != ""
}
