# Terraform remote state account. Adopted from bootstrap-init.sh on first apply
# (see make bootstrap-import), then reconciled to this desired state.
#
# Posture:
# - RA-GRS, StorageV2, TLS 1.2, infrastructure (double) encryption.
# - Entra-ID-only data plane: shared_access_key_enabled = false. The backend
#   and this provider authenticate with use_azuread_auth / storage_use_azuread.
# - Blob versioning + soft delete protect state history; blob lease provides
#   Terraform state locking.
# - CMK via the seed Key Vault (azurerm_storage_account_customer_managed_key).
# - Phase 1 firewall: default-deny + break-glass IP allowlist + AzureServices
#   bypass. Phase 2 (Stage 03) retrofits Private Endpoints (ADR-0048).
resource "azurerm_storage_account" "tfstate" {
  #checkov:skip=CKV_AZURE_59:Phase 1 public endpoint with default-deny IP allowlist; Private Endpoint retrofit in Stage 03 (ADR-0048 / ADR-0031).
  #checkov:skip=CKV2_AZURE_33:No VNet exists in Phase 1; Private Endpoint is added in Stage 03 (ADR-0048).
  #checkov:skip=CKV_AZURE_33:State account exposes the blob service only; the queue service is not used.
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  account_kind             = "StorageV2"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cmk.id]
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = local.firewall_ip_rules
  }

  lifecycle {
    # CMK association is managed by azurerm_storage_account_customer_managed_key.
    # AzureRM also reads it back as a nested storage account block, so ignoring
    # the read-only mirror prevents a follow-up plan from removing the CMK.
    ignore_changes = [customer_managed_key]
  }

  tags = local.tags
}

# One container per stage plus per-profile env state (plan.md section 8).
# The "bootstrap" container is adopted; the rest are created here.
resource "azurerm_storage_container" "stage" {
  #checkov:skip=CKV2_AZURE_21:Blob read/write/delete is logged via azurerm_monitor_diagnostic_setting.tfstate_blob; checkov cannot statically trace the interpolated blobServices target_resource_id.
  for_each              = toset(var.state_containers)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# Encrypt the state account with the customer-managed key once RBAC has
# propagated to the state account identity.
resource "azurerm_storage_account_customer_managed_key" "tfstate" {
  storage_account_id        = azurerm_storage_account.tfstate.id
  key_vault_id              = azurerm_key_vault.bootstrap.id
  key_name                  = azurerm_key_vault_key.state_cmk.name
  user_assigned_identity_id = azurerm_user_assigned_identity.cmk.id

  depends_on = [time_sleep.cmk_rbac]
}

# Audit every read/write/delete against Terraform state to the bootstrap
# workspace. State access is security-sensitive, so this is enabled from day one
# rather than waiting for the Stage 02 central logging build-out.
resource "azurerm_monitor_diagnostic_setting" "tfstate_blob" {
  name                       = "diag-tfstate-blob"
  target_resource_id         = "${azurerm_storage_account.tfstate.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.bootstrap.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}
