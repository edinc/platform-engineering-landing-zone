provider "azurerm" {
  features {}

  # The management subscription hosts the central Log Analytics workspace,
  # Defender for Cloud plans, budgets, and the Cost Management export storage.
  # Management-group and policy resources are tenant-scoped but are issued
  # through this subscription's ARM endpoint.
  subscription_id = var.management_subscription_id
  tenant_id       = var.tenant_id

  # Required resource providers (Microsoft.Management, Microsoft.PolicyInsights,
  # Microsoft.Security, Microsoft.OperationalInsights, Microsoft.Insights,
  # Microsoft.CostManagementExports, Microsoft.Storage) are pre-registered on the
  # management subscription as a documented prerequisite (see README), so the
  # provider must not attempt registration on configure.
  resource_provider_registrations = "none"

  # The Cost Management export storage account is Entra-ID-only
  # (shared_access_key_enabled = false); container creation uses AAD.
  storage_use_azuread = true
}
