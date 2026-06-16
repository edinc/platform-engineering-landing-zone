output "namespace" {
  value       = var.namespace
  description = "Vended Kubernetes namespace."
}

output "manifest_directory" {
  value       = local.tenant_output_directory
  description = "Directory containing rendered Flux-compatible tenant bootstrap and workload manifests."
}

output "flux_kustomization_file" {
  value       = local_file.flux_kustomization.filename
  description = "Rendered Flux Kustomization file that points at the namespace manifest directory."
}

output "manifest_files" {
  value       = { for name, file in local_file.manifests : name => file.filename }
  description = "Rendered manifest files keyed by filename."
}

output "workload_identity_client_id" {
  value       = azurerm_user_assigned_identity.workload.client_id
  description = "Client ID annotated onto the vended ServiceAccount."
}

output "workload_identity_principal_id" {
  value       = azurerm_user_assigned_identity.workload.principal_id
  description = "Principal ID granted ACR pull and Key Vault read roles."
}

output "aks_namespace_reader_assignment_id" {
  value       = azurerm_role_assignment.aks_namespace_reader.id
  description = "Namespace-scoped AKS Azure RBAC Reader assignment for the team's Entra group. Writes flow through GitOps."
}

output "aks_namespace_writer_assignment_id" {
  value       = azurerm_role_assignment.aks_namespace_reader.id
  description = "Deprecated compatibility output. Use aks_namespace_reader_assignment_id; the assignment is intentionally read-only because writes flow through GitOps."
}

output "cluster_state_path" {
  value       = "tenants/${var.team_name}/${var.environment}/${var.namespace}"
  description = "Destination tenant path in platform-cluster-state."
}

output "cluster_state_flux_file" {
  value       = "clusters/overlays/${var.environment}/tenants/${var.team_name}-${var.namespace}-flux-kustomization.yaml"
  description = "Destination Flux Kustomization file in platform-cluster-state, indexed by the environment overlay."
}

output "backend_config_hint" {
  value = {
    container_name   = "vending"
    key              = "namespaces/${var.team_name}/${var.environment}/${var.namespace}/terraform.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
