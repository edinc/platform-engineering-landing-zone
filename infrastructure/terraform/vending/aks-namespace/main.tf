resource "azurerm_user_assigned_identity" "workload" {
  name                = local.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    env                = var.environment
    owner              = var.team_name
    costCenter         = var.cost_center
    product            = var.product
    dataClassification = var.data_classification
    confidentiality    = var.environment == "prod" ? "high" : "medium"
    managedBy          = "terraform"
    repo               = "edinc/platform-engineering-landing-zone"
  }
}

resource "azurerm_federated_identity_credential" "workload" {
  name                = "fic-${var.namespace}-${var.service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  for_each = toset(var.key_vault_secret_ids)

  scope                = each.value
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "aks_namespace_reader" {
  scope                = "${var.aks_cluster_id}/namespaces/${var.namespace}"
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = var.entra_group_object_id
  principal_type       = "Group"
}

moved {
  from = azurerm_role_assignment.aks_namespace_writer
  to   = azurerm_role_assignment.aks_namespace_reader
}

resource "local_file" "manifests" {
  for_each = local.manifests

  filename             = "${local.namespace_output_directory}/${each.key}"
  content              = "${each.value}\n"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [
    azurerm_federated_identity_credential.workload,
    azurerm_role_assignment.aks_namespace_reader,
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.key_vault_secrets_user,
  ]
}

resource "local_file" "workload_kustomization" {
  filename             = "${local.workload_output_directory}/kustomization.yaml"
  content              = "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources: []\n"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [local_file.manifests]
}

resource "local_file" "flux_kustomization" {
  filename             = "${local.parent_output_directory}/${var.namespace}-flux-kustomization.yaml"
  content              = "${local.flux_kustomization}\n"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [
    local_file.manifests,
    local_file.workload_kustomization,
  ]
}
