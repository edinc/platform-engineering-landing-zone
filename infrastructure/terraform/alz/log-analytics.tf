# Central Log Analytics workspace (management subscription). This is the
# concrete destination for the platform-wide diagnostic-settings DINE policy
# (assignments.tf) and the Defender for Cloud workspace export configured by
# later stages.
resource "azurerm_log_analytics_workspace" "central" {
  name                = local.log_analytics_name
  resource_group_name = azurerm_resource_group.management.name
  location            = azurerm_resource_group.management.location

  sku               = "PerGB2018"
  retention_in_days = var.log_analytics_retention_days

  # Data-collection access is via Entra ID; do not expose the workspace shared
  # keys for ingestion.
  local_authentication_enabled = false

  tags = local.tags
}
