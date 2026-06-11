output "github_app_id" {
  value       = var.github_app_id
  description = "platform-vending-bot App ID used by actions/create-github-app-token."
}

output "github_app_installation_id" {
  value       = var.github_app_installation_id
  description = "platform-vending-bot installation ID."
}

output "private_key_secret_name" {
  value       = var.private_key_secret_name
  description = "Seed Key Vault secret name that stores the GitHub App private key. Terraform does not manage the secret value."
}

output "seed_key_vault_id" {
  value       = var.seed_key_vault_id
  description = "Seed Key Vault resource ID operators use for private-key rotation."
}

output "private_key_rotation_due_date" {
  value       = var.private_key_rotation_due_date
  description = "Operator rotation due date for the platform-vending-bot private key."
}

output "installation_repository_names" {
  value       = sort(keys(github_app_installation_repository.vending_bot))
  description = "Repositories selected for the platform-vending-bot installation."
}

output "backend_config_hint" {
  value = {
    container_name   = "vending"
    key              = "github-app/platform-vending-bot.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
