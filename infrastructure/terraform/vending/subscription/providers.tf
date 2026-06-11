provider "azapi" {
  subscription_id = var.vending_subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  features {}

  subscription_id = var.vending_subscription_id
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"
  storage_use_azuread             = true
}
