resource "terraform_data" "input_guard" {
  input = {
    github_app_id                 = var.github_app_id
    github_app_installation_id    = var.github_app_installation_id
    installation_repository_names = var.installation_repository_names
    private_key_secret_name       = var.private_key_secret_name
    private_key_rotation_due_date = var.private_key_rotation_due_date
    seed_key_vault_id             = var.seed_key_vault_id
  }

  lifecycle {
    precondition {
      condition     = contains(var.installation_repository_names, "platform-engineering-landing-zone") && contains(var.installation_repository_names, "platform-cluster-state")
      error_message = "platform-vending-bot must be installed on platform-engineering-landing-zone and platform-cluster-state."
    }
  }
}

resource "github_app_installation_repository" "vending_bot" {
  for_each = toset(var.installation_repository_names)

  installation_id = var.github_app_installation_id
  repository      = each.value

  depends_on = [terraform_data.input_guard]
}
