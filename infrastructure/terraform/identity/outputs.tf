output "group_object_ids" {
  value       = local.group_object_ids
  description = "Object IDs for all Entra groups created by the connectivity & egress identity stack."
}

output "platform_group_display_names" {
  value       = { for key, group in azuread_group.this : key => group.display_name }
  description = "Display names for platform and app-team groups."
}

output "platform_operator_role_definition_id" {
  value       = try(azurerm_role_definition.platform_operator[0].role_definition_resource_id, null)
  description = "Scoped resource ID for the custom Platform Operator role, or null when disabled."
}

output "platform_reader_assignment_id" {
  value       = try(azurerm_role_assignment.platform_readers[0].id, null)
  description = "Default Reader assignment ID for pe-platform-readers."
}

output "platform_operator_pim_assignment_id" {
  value       = try(azurerm_pim_eligible_role_assignment.platform_operators[0].id, null)
  description = "Default PIM eligible assignment ID for pe-platform-operators, or null when PIM/default assignments are disabled."
}

output "backend_config_hint" {
  value = {
    container_name   = "identity"
    key              = "${var.environment}/identity.tfstate"
    use_azuread_auth = true
  }
  description = "Backend settings for this stack's state. resource_group_name and storage_account_name come from the _bootstrap outputs."
}
