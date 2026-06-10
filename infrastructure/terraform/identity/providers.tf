provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"
  storage_use_azuread             = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}
