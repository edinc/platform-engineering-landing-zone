output "entra_group_object_id" {
  value       = azuread_group.app_team.object_id
  description = "Object ID for pe-app-team-<team>; consumed by AKS namespace vending."
}

output "entra_group_display_name" {
  value       = azuread_group.app_team.display_name
  description = "Display name for the app-team Entra group."
}

output "backstage_group_ref" {
  value       = "group:default/${azuread_group.app_team.display_name}"
  description = "Backstage group ref reconciled from Microsoft Graph."
}

output "github_team_slug" {
  value       = github_team.app_team.slug
  description = "GitHub team slug for repository permissions."
}

output "cost_allocation" {
  value = {
    team               = var.team_name
    product            = var.product_name
    costCenter         = var.cost_center
    onCallRotationId   = var.on_call_rotation_id
    dataClassification = var.data_classification
    backstageOwner     = "group:default/${azuread_group.app_team.display_name}"
  }
  description = "Cost allocation metadata consumed by Stage 08 showback and Backstage Cost Insights."
}
