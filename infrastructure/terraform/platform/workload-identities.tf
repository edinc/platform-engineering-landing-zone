locals {
  platform_workload_identity_specs = {
    cert_manager = {
      enabled              = local.gitops_enabled && var.cert_manager_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-cert-manager"
      namespace            = "cert-manager"
      service_account_name = "cert-manager"
    }
    external_dns = {
      enabled              = local.gitops_enabled && var.external_dns_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-external-dns"
      namespace            = "external-dns"
      service_account_name = "external-dns"
    }
    external_secrets = {
      enabled              = local.gitops_enabled && var.external_secrets_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-external-secrets"
      namespace            = "external-secrets"
      service_account_name = "external-secrets"
    }
    aso = {
      enabled              = local.gitops_enabled && var.aso_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-aso"
      namespace            = "azureserviceoperator-system"
      service_account_name = "azure-service-operator"
    }
    flux_source = {
      enabled              = local.gitops_enabled
      name                 = "id-${local.name_prefix}-flux-source"
      namespace            = var.gitops_flux_namespace
      service_account_name = "source-controller"
    }
    backstage = {
      enabled              = local.backstage_enabled && var.backstage_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-backstage"
      namespace            = "backstage"
      service_account_name = "backstage"
    }
    backstage_catalog_reconciler = {
      enabled              = local.backstage_enabled && var.backstage_catalog_reconciler_workload_identity_client_id == ""
      name                 = "id-${local.name_prefix}-backstage-reconciler"
      namespace            = "backstage"
      service_account_name = "backstage-catalog-reconciler"
    }
  }

  cert_manager_workload_identity_client_id = (
    var.cert_manager_workload_identity_client_id != "" ? var.cert_manager_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["cert_manager"].client_id, "")
  )
  external_dns_workload_identity_client_id = (
    var.external_dns_workload_identity_client_id != "" ? var.external_dns_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["external_dns"].client_id, "")
  )
  external_secrets_workload_identity_client_id = (
    var.external_secrets_workload_identity_client_id != "" ? var.external_secrets_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["external_secrets"].client_id, "")
  )
  aso_workload_identity_client_id = (
    var.aso_workload_identity_client_id != "" ? var.aso_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["aso"].client_id, "")
  )
  flux_source_workload_identity_client_id    = try(azurerm_user_assigned_identity.platform_workload["flux_source"].client_id, "")
  flux_source_workload_identity_principal_id = try(azurerm_user_assigned_identity.platform_workload["flux_source"].principal_id, "")
  backstage_workload_identity_client_id = (
    var.backstage_workload_identity_client_id != "" ? var.backstage_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["backstage"].client_id, "")
  )
  backstage_workload_identity_principal_id = (
    var.backstage_workload_identity_principal_id != "" ? var.backstage_workload_identity_principal_id : try(azurerm_user_assigned_identity.platform_workload["backstage"].principal_id, "")
  )
  backstage_catalog_reconciler_workload_identity_client_id = (
    var.backstage_catalog_reconciler_workload_identity_client_id != "" ? var.backstage_catalog_reconciler_workload_identity_client_id : try(azurerm_user_assigned_identity.platform_workload["backstage_catalog_reconciler"].client_id, "")
  )
  backstage_catalog_reconciler_workload_identity_principal_id = (
    var.backstage_catalog_reconciler_workload_identity_principal_id != "" ? var.backstage_catalog_reconciler_workload_identity_principal_id : try(azurerm_user_assigned_identity.platform_workload["backstage_catalog_reconciler"].principal_id, "")
  )
}

resource "azurerm_user_assigned_identity" "platform_workload" {
  for_each = {
    for key, spec in local.platform_workload_identity_specs : key => spec
    if spec.enabled
  }

  name                = each.value.name
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "platform_workload" {
  for_each = azurerm_user_assigned_identity.platform_workload

  name                = "fic-${local.platform_workload_identity_specs[each.key].namespace}-${local.platform_workload_identity_specs[each.key].service_account_name}"
  resource_group_name = azurerm_resource_group.platform.name
  parent_id           = each.value.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.platform[0].oidc_issuer_url
  subject             = "system:serviceaccount:${local.platform_workload_identity_specs[each.key].namespace}:${local.platform_workload_identity_specs[each.key].service_account_name}"
}

resource "azurerm_role_assignment" "cert_manager_dns" {
  provider = azurerm.dns
  count    = local.gitops_enabled && var.cert_manager_workload_identity_client_id == "" ? 1 : 0

  scope                = "/subscriptions/${var.private_dns_zone_subscription_id != "" ? var.private_dns_zone_subscription_id : var.subscription_id}/resourceGroups/${var.azure_dns_resource_group_name}/providers/Microsoft.Network/dnsZones/${var.platform_root_domain}"
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.platform_workload["cert_manager"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "external_dns" {
  provider = azurerm.dns
  count    = local.gitops_enabled && var.external_dns_workload_identity_client_id == "" ? 1 : 0

  scope                = "/subscriptions/${var.private_dns_zone_subscription_id != "" ? var.private_dns_zone_subscription_id : var.subscription_id}/resourceGroups/${var.azure_dns_resource_group_name}/providers/Microsoft.Network/dnsZones/${var.platform_root_domain}"
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.platform_workload["external_dns"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cert_manager_key_vault_secret_user" {
  for_each = local.gitops_enabled && var.cert_manager_workload_identity_client_id == "" ? toset([
    "platform-private-ca-crt",
    "platform-private-ca-key",
  ]) : toset([])

  scope                = "${azurerm_key_vault.platform[0].id}/secrets/${each.value}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.platform_workload["cert_manager"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "external_secrets_key_vault_secret_user" {
  for_each = local.gitops_enabled && var.external_secrets_workload_identity_client_id == "" ? toset([
    "platform-rightsizing-github-repository",
    "platform-rightsizing-github-token",
  ]) : toset([])

  scope                = "${azurerm_key_vault.platform[0].id}/secrets/${each.value}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.platform_workload["external_secrets"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_definition" "aso_platform_operator" {
  count = local.gitops_enabled && var.aso_workload_identity_client_id == "" ? 1 : 0

  name        = "Platform ASO Operator ${local.name_prefix}"
  scope       = azurerm_resource_group.platform.id
  description = "Least-privilege management-plane role for ASO-managed workload dependencies in the platform resource group."

  permissions {
    actions = [
      "Microsoft.DBforPostgreSQL/flexibleServers/databases/*",
      "Microsoft.DBforPostgreSQL/flexibleServers/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.ServiceBus/namespaces/read",
      "Microsoft.ServiceBus/namespaces/topics/*",
      "Microsoft.Storage/storageAccounts/blobServices/containers/*",
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.platform.id,
  ]
}

resource "azurerm_role_assignment" "aso_platform_operator" {
  count = local.gitops_enabled && var.aso_workload_identity_client_id == "" ? 1 : 0

  scope              = azurerm_resource_group.platform.id
  role_definition_id = azurerm_role_definition.aso_platform_operator[0].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.platform_workload["aso"].principal_id
  principal_type     = "ServicePrincipal"
}
