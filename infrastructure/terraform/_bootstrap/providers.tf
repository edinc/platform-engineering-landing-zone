provider "azurerm" {
  features {
    key_vault {
      # Keep purge protection meaningful: never auto-purge on destroy, and
      # recover soft-deleted vaults instead of failing on name reuse.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # The bootstrap deploy identity has only resource-group-scoped Contributor and
  # cannot register resource providers at subscription scope. bootstrap-init.sh
  # (run by a Global Admin) pre-registers the namespaces Terraform needs, so the
  # provider must not attempt registration on configure (azurerm v4 otherwise
  # defaults to "core", which fails for this least-privilege identity on a fresh
  # subscription).
  resource_provider_registrations = "none"

  # State and Key Vault data-plane access use Entra ID, not storage account
  # keys (shared_access_key_enabled = false on the state account).
  storage_use_azuread = true
}
