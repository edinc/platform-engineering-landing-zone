# Resource group in the management subscription holding the central Log
# Analytics workspace and the Cost Management export storage account.
resource "azurerm_resource_group" "management" {
  name     = local.management_rg_name
  location = var.location
  tags     = local.tags
}
