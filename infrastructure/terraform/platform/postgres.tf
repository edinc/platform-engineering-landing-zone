resource "azurerm_postgresql_flexible_server" "platform" {
  count = var.enable_postgres ? 1 : 0

  #checkov:skip=CKV_SECRET_6:Password is a sensitive Terraform variable supplied out of band; no concrete secret is committed.
  name                          = local.postgres_name
  resource_group_name           = azurerm_resource_group.platform.name
  location                      = azurerm_resource_group.platform.location
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.platform["postgres-delegated"].id
  private_dns_zone_id           = var.private_dns_zone_ids[local.postgres_private_dns_zone_name]
  public_network_access_enabled = false
  administrator_login           = var.postgres_administrator_login
  administrator_password        = var.postgres_administrator_password
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = var.profile == "prod"
  auto_grow_enabled             = true
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  zone                          = length(var.availability_zones) > 0 ? var.availability_zones[0] : null
  tags                          = local.tags

  authentication {
    password_auth_enabled = true
  }

  dynamic "high_availability" {
    for_each = var.profile == "prod" && length(var.availability_zones) > 1 ? [1] : []

    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.availability_zones[1]
    }
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.platform]
}

resource "azurerm_postgresql_flexible_server_database" "backstage" {
  count = var.enable_postgres ? 1 : 0

  name      = "backstage"
  server_id = azurerm_postgresql_flexible_server.platform[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
