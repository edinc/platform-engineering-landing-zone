# Resource group for Terraform remote state, the seed Key Vault, and bootstrap
# monitoring. Adopted from bootstrap-init.sh on first apply (see make
# bootstrap-import).
resource "azurerm_resource_group" "tfstate" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# Seed Key Vault for bootstrap-time secrets and the state customer-managed key.
# Phase 1 posture: public endpoint with default-deny firewall + IP allowlist +
# trusted Azure services bypass (required for Storage CMK access). Phase 2
# (Stage 03) retrofits Private Endpoints and disables public access
# (ADR-0048 / ADR-0031). RBAC authorization only; no access policies.
resource "azurerm_key_vault" "bootstrap" {
  #checkov:skip=CKV_AZURE_109:Default firewall action is Deny by default and guarded by lifecycle precondition; Checkov does not resolve the variable/precondition pair.
  #checkov:skip=CKV_AZURE_189:Phase 1 public endpoint with default-deny IP allowlist; public access is disabled when the Private Endpoint lands in Stage 03 (ADR-0048 / ADR-0031).
  #checkov:skip=CKV2_AZURE_32:No VNet exists in Phase 1; the Key Vault Private Endpoint is added in Stage 03 (ADR-0048).
  name                       = local.key_vault_name
  resource_group_name        = azurerm_resource_group.tfstate.name
  location                   = azurerm_resource_group.tfstate.location
  tenant_id                  = var.tenant_id
  sku_name                   = var.key_vault_sku
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = var.soft_delete_retention_days

  public_network_access_enabled = true

  network_acls {
    default_action = var.firewall_default_action
    bypass         = "AzureServices"
    ip_rules       = local.firewall_ip_rules
  }

  lifecycle {
    precondition {
      condition = (
        var.firewall_default_action == "Deny" ||
        local.firewall_allow_permitted
      )
      error_message = "firewall_default_action = Allow is only permitted for local recovery/integration when local_recovery_mode_enabled is true, runner_ip_cidrs is empty, and local_recovery_mode_acknowledgement matches the documented phrase."
    }
  }

  tags = local.tags
}

# User-assigned identity used by the state storage account to reach the CMK.
resource "azurerm_user_assigned_identity" "cmk" {
  name                = local.uami_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tags                = local.tags
}

# Allow the state account identity to wrap/unwrap with the CMK.
resource "azurerm_role_assignment" "cmk_kv" {
  scope                = azurerm_key_vault.bootstrap.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.cmk.principal_id
}

# Customer-managed key for Terraform state encryption.
resource "azurerm_key_vault_key" "state_cmk" {
  #checkov:skip=CKV_AZURE_112:HSM-backed keys are optional in Stage 01; opt in by setting key_vault_sku = premium and key_type = RSA-HSM (var.key_type).
  #checkov:skip=CKV_AZURE_40:The CMK uses rotation_policy (auto-rotate + expire_after) instead of a static expiration_date; a hard expiry on the state-encryption key risks locking out all remote state.
  name         = local.cmk_key_name
  key_vault_id = azurerm_key_vault.bootstrap.id
  key_type     = var.key_type
  key_size     = 3072

  key_opts = [
    "unwrapKey",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P29D"
  }

  tags = local.tags
}

# Give Azure RBAC role propagation time to settle before the storage account
# attempts to reach the key, which otherwise fails intermittently.
resource "time_sleep" "cmk_rbac" {
  depends_on      = [azurerm_role_assignment.cmk_kv]
  create_duration = "60s"
}
