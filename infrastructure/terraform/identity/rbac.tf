resource "azurerm_role_definition" "platform_operator" {
  count = var.enable_platform_operator_role ? 1 : 0

  name        = local.platform_operator_role_name
  scope       = local.platform_operator_scope
  description = "Platform operations role without IAM mutation. See ADR-0029."

  permissions {
    actions = [
      "*/read",
      "Microsoft.AlertsManagement/actionRules/read",
      "Microsoft.AlertsManagement/alerts/changestate/action",
      "Microsoft.AlertsManagement/alerts/read",
      "Microsoft.AlertsManagement/smartDetectorAlertRules/read",
      "Microsoft.ContainerRegistry/registries/read",
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/start/action",
      "Microsoft.ContainerService/managedClusters/stop/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/read",
      "Microsoft.DBforPostgreSQL/flexibleServers/start/action",
      "Microsoft.DBforPostgreSQL/flexibleServers/stop/action",
      "Microsoft.Insights/*/read",
      "Microsoft.Insights/eventtypes/*",
      "Microsoft.Insights/metrics/read",
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.Network/*/read",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/subscriptions/resourceGroups/*",
      "Microsoft.Resources/tags/*",
      "Microsoft.ServiceBus/namespaces/read",
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/fileServices/read",
      "Microsoft.Storage/storageAccounts/queueServices/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/tableServices/read",
      "Microsoft.Support/*",
    ]
    not_actions = [
      "Microsoft.Authorization/*/Delete",
      "Microsoft.Authorization/*/Write",
      "Microsoft.Authorization/elevateAccess/Action",
      "Microsoft.Blueprint/blueprintAssignments/delete",
      "Microsoft.Blueprint/blueprintAssignments/write",
      "Microsoft.ContainerRegistry/registries/generateCredentials/action",
      "Microsoft.ContainerRegistry/registries/listCredentials/action",
      "Microsoft.ContainerRegistry/registries/regenerateCredential/action",
      "Microsoft.ContainerRegistry/registries/tokens/delete",
      "Microsoft.ContainerRegistry/registries/tokens/listCredentials/action",
      "Microsoft.ContainerRegistry/registries/tokens/write",
      "Microsoft.Compute/galleries/share/action",
      "Microsoft.ContainerService/managedClusters/accessProfiles/listCredential/action",
      "Microsoft.ContainerService/managedClusters/commandResults/read",
      "Microsoft.ContainerService/managedClusters/listClusterAdminCredential/action",
      "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
      "Microsoft.ContainerService/managedClusters/runCommand/action",
      "Microsoft.Purview/consents/delete",
      "Microsoft.Purview/consents/write",
      "Microsoft.ServiceBus/namespaces/authorizationRules/listKeys/action",
      "Microsoft.ServiceBus/namespaces/authorizationRules/regenerateKeys/action",
      "Microsoft.Storage/storageAccounts/listAccountSas/action",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      "Microsoft.Storage/storageAccounts/listServiceSas/action",
      "Microsoft.Storage/storageAccounts/regenerateKey/action",
    ]
    data_actions     = []
    not_data_actions = []
  }

  assignable_scopes = local.role_assignable_scopes
}

resource "azurerm_role_assignment" "platform_readers" {
  count = var.enable_default_assignments ? 1 : 0

  scope                = local.subscription_scope
  role_definition_name = "Reader"
  principal_id         = local.group_object_ids.platform_readers
  principal_type       = "Group"
  description          = "Stage 03 default group-only Reader assignment."
}

resource "azurerm_role_assignment" "platform_operators_active" {
  count = var.enable_default_assignments && var.enable_platform_operator_role && !var.pim_enabled ? 1 : 0

  scope              = local.subscription_scope
  role_definition_id = azurerm_role_definition.platform_operator[0].role_definition_resource_id
  principal_id       = local.group_object_ids.platform_operators
  principal_type     = "Group"
  description        = "Stage 03 fallback active Platform Operator assignment when PIM is disabled."
}

resource "azurerm_role_assignment" "additional" {
  for_each = var.additional_active_role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  role_definition_id   = each.value.role_definition_id
  principal_id         = local.group_object_ids[each.value.group_key]
  principal_type       = "Group"
  description          = coalesce(each.value.description, "Stage 03 group-only role assignment.")

  depends_on = [terraform_data.input_guard]
}
