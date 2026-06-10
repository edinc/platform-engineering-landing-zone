output "repository_name" {
  value       = github_repository.cluster_state.name
  description = "Cluster-state repository name."
}

output "repository_full_name" {
  value       = github_repository.cluster_state.full_name
  description = "Cluster-state repository full name."
}

output "repository_http_clone_url" {
  value       = github_repository.cluster_state.http_clone_url
  description = "HTTPS clone URL for the cluster-state repository."
}

output "default_branch" {
  value       = github_branch_default.cluster_state.branch
  description = "Default branch configured for the cluster-state repository."
}

output "backend_config_hint" {
  value = {
    container_name   = "platform"
    key              = "cluster-state-repo/terraform.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
