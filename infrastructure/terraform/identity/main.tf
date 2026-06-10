data "azuread_client_config" "current" {}

resource "terraform_data" "input_guard" {
  input = {
    additional_active_role_assignments       = var.additional_active_role_assignments
    additional_pim_eligible_role_assignments = var.additional_pim_eligible_role_assignments
    pim_approval_group_key                   = var.pim_approval_group_key
  }

  lifecycle {
    precondition {
      condition     = contains(local.valid_group_keys, var.pim_approval_group_key)
      error_message = "pim_approval_group_key must reference one of the created platform or app-team groups."
    }

    precondition {
      condition = (
        !var.enable_default_assignments ||
        !var.enable_platform_operator_role ||
        contains(local.role_assignable_scopes, local.subscription_scope)
      )
      error_message = "role_assignable_scopes must include the target subscription scope when default Platform Operator assignments are enabled."
    }

    precondition {
      condition     = var.environment != "prod" || var.pim_enabled
      error_message = "prod requires pim_enabled = true. Use the break-glass process for exceptional active privileged access."
    }

    precondition {
      condition     = var.environment != "prod" || var.pim_require_approval_for_prod
      error_message = "prod requires pim_require_approval_for_prod = true."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_active_role_assignments) :
        contains(local.valid_group_keys, assignment.group_key)
      ])
      error_message = "Every additional_active_role_assignments group_key must reference a created group."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_active_role_assignments) :
        assignment.role_definition_name != null && assignment.role_definition_id == null
      ])
      error_message = "Each additional active assignment must set role_definition_name only. Use PIM for role_definition_id or privileged assignments."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_active_role_assignments) :
        assignment.role_definition_name != null && contains(local.allowed_active_role_definition_names, assignment.role_definition_name)
      ])
      error_message = "additional_active_role_assignments may only use allowed_active_role_definition_names. Privileged roles must use PIM."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_active_role_assignments) :
        startswith(assignment.scope, "/subscriptions/")
      ])
      error_message = "additional_active_role_assignments scopes must stay under /subscriptions/. Management-group scopes are owned by the external ALZ."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_pim_eligible_role_assignments) :
        contains(local.valid_group_keys, assignment.group_key)
      ])
      error_message = "Every additional_pim_eligible_role_assignments group_key must reference a created group."
    }

    precondition {
      condition = alltrue([
        for assignment in values(var.additional_pim_eligible_role_assignments) :
        startswith(assignment.scope, "/subscriptions/")
      ])
      error_message = "additional_pim_eligible_role_assignments scopes must stay under /subscriptions/. Management-group scopes are owned by the external ALZ."
    }
  }
}

resource "azuread_group" "this" {
  for_each = local.groups

  display_name            = each.value.display_name
  description             = each.value.description
  owners                  = local.group_owner_object_ids
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true
}
