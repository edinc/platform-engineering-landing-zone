# Cost Management daily exports land in this ADLS Gen2 account in the management
# subscription (acceptance criterion 5).
#
# Posture mirrors the state account (ADR-0014): TLS 1.2, Entra-ID-only data plane
# (shared_access_key_enabled = false), infrastructure (double) encryption,
# default-deny firewall + AzureServices bypass so Cost Management can write,
# blob versioning + soft delete. Phase 1 keeps a public endpoint behind the
# firewall; Stage 03 retrofits a Private Endpoint (ADR-0048).
resource "azurerm_storage_account" "cost" {
  #checkov:skip=CKV_AZURE_59:Phase 1 public endpoint with default-deny IP allowlist + AzureServices bypass for Cost Management; Private Endpoint retrofit in Stage 03 (ADR-0048).
  #checkov:skip=CKV2_AZURE_33:No VNet exists in this stack; Private Endpoint is added in Stage 03 (ADR-0048).
  #checkov:skip=CKV_AZURE_33:Cost export account exposes the blob service only; the queue service is not used.
  #checkov:skip=CKV2_AZURE_1:Cost export data is platform-managed billing data protected by infrastructure (double) encryption; customer-managed key is a documented future enhancement, not required at Stage 02.
  #checkov:skip=CKV2_AZURE_21:Blob access is auditable via diagnostic settings added with the workspace; checkov cannot statically trace the interpolated blobServices target.
  #checkov:skip=CKV2_AZURE_38:Soft delete is enabled via blob_properties.delete_retention_policy; the versioning + container retention combination is the same hardening used by the state account.
  #checkov:skip=CKV2_AZURE_40:Entra-ID-only data plane (shared_access_key_enabled = false) already disables shared-key authorization.
  #checkov:skip=CKV2_AZURE_41:SAS is not used; the data plane is Entra-ID-only.
  #checkov:skip=CKV_AZURE_206:Cost exports are regenerable daily billing data; the management account uses LRS for the cost-conscious profile, GRS is a documented future enhancement, not required at Stage 02 (ADR-0011).
  name                = local.cost_storage_account_name
  resource_group_name = azurerm_resource_group.management.name
  location            = azurerm_resource_group.management.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.cost_export_storage_ip_rules
  }

  tags = local.tags
}

resource "azurerm_storage_container" "cost" {
  #checkov:skip=CKV2_AZURE_21:Blob access is auditable via diagnostic settings; checkov cannot statically trace the interpolated blobServices target.
  # Uses storage_account_id (ARM resource ID), so container creation goes through
  # the Storage resource provider (management plane) and is NOT blocked by the
  # account's default-deny data-plane firewall. Do not switch to the legacy
  # storage_account_name form (data plane), which would require JIT IP
  # allowlisting like the _bootstrap state container.
  name                  = local.cost_export_container
  storage_account_id    = azurerm_storage_account.cost.id
  container_access_type = "private"
}

# Lifecycle: tier exported cost blobs to cool, then delete after the retention
# window, so the export account does not grow unbounded.
resource "azurerm_storage_management_policy" "cost" {
  storage_account_id = azurerm_storage_account.cost.id

  rule {
    name    = "expire-cost-exports"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${local.cost_export_container}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than       = var.cost_export_retention_days
      }
    }
  }
}

# Daily actual-cost export for the management subscription. Operators add further
# per-subscription exports as subscriptions are vended.
resource "azurerm_subscription_cost_management_export" "management" {
  name                         = "export-pe-management-daily"
  subscription_id              = "/subscriptions/${var.management_subscription_id}"
  recurrence_type              = "Daily"
  recurrence_period_start_date = var.cost_export_recurrence_from
  recurrence_period_end_date   = var.cost_export_recurrence_to

  export_data_storage_location {
    container_id     = azurerm_storage_container.cost.id
    root_folder_path = "management"
  }

  export_data_options {
    type       = "ActualCost"
    time_frame = "MonthToDate"
  }
}

# Optional: grant the Cost Management export service principal write access to the
# export account. The v4 export resource has no managed-identity block, so the
# principal object ID is supplied out of band (var.cost_management_principal_id);
# otherwise grant Storage Blob Data Contributor manually (documented in README).
resource "azurerm_role_assignment" "cost_export_writer" {
  count = var.cost_management_principal_id != "" ? 1 : 0

  scope                = azurerm_storage_account.cost.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.cost_management_principal_id
}
