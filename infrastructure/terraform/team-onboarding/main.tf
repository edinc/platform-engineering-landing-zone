data "azuread_client_config" "current" {}

resource "azuread_group" "app_team" {
  display_name            = local.entra_group_display_name
  description             = "Application team group for ${var.team_name}; product=${var.product_name}; costCenter=${var.cost_center}; dataClassification=${var.data_classification}; onCall=${var.on_call_rotation_id}."
  owners                  = local.group_owner_object_ids
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true
}

resource "github_team" "app_team" {
  name           = local.github_team_name
  description    = "Application team ${var.team_name}; product=${var.product_name}; costCenter=${var.cost_center}; dataClassification=${var.data_classification}; onCall=${var.on_call_rotation_id}."
  privacy        = "closed"
  parent_team_id = var.github_parent_team_id
}

resource "github_team_repository" "default_permissions" {
  for_each = var.github_repository_permissions

  team_id    = github_team.app_team.id
  repository = each.key
  permission = each.value
}
