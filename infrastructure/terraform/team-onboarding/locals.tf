locals {
  entra_group_display_name = "${var.platform_group_prefix}-app-team-${var.team_name}"
  github_team_name         = var.github_team_name != "" ? var.github_team_name : "app-team-${var.team_name}"
  group_owner_object_ids   = length(var.group_owners_object_ids) > 0 ? var.group_owners_object_ids : [data.azuread_client_config.current.object_id]
}
