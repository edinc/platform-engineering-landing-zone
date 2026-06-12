provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"
  storage_use_azuread             = true
}

provider "azurerm" {
  alias = "dns"

  features {}

  subscription_id = var.private_dns_zone_subscription_id != "" ? var.private_dns_zone_subscription_id : var.subscription_id
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"
  storage_use_azuread             = true
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
