provider "azurerm" {
  features {}

  # The subscription baseline now targets one existing subscription. Tenant-wide ALZ resources
  # (management groups, policy definitions, shared workspaces/storage) are owned
  # outside this stack and passed in as resource IDs when needed.
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Required resource providers are pre-registered by the existing ALZ/platform
  # operating model, so the provider must not attempt registration on configure.
  resource_provider_registrations = "none"
}
