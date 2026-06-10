resource "azurerm_role_management_policy" "platform_operator" {
  count = var.enable_platform_operator_role && var.pim_enabled ? 1 : 0

  scope              = local.subscription_scope
  role_definition_id = azurerm_role_definition.platform_operator[0].role_definition_resource_id

  eligible_assignment_rules {
    expiration_required = false
  }

  active_assignment_rules {
    expiration_required                = true
    expire_after                       = "P90D"
    require_justification              = true
    require_multifactor_authentication = true
  }

  activation_rules {
    maximum_duration                   = var.pim_maximum_duration
    require_approval                   = local.pim_requires_approval
    require_justification              = true
    require_multifactor_authentication = true
    require_ticket_info                = true

    dynamic "approval_stage" {
      for_each = local.pim_requires_approval ? [1] : []

      content {
        primary_approver {
          object_id = local.group_object_ids[var.pim_approval_group_key]
          type      = "Group"
        }
      }
    }
  }
}

resource "azurerm_pim_eligible_role_assignment" "platform_operators" {
  count = var.enable_default_assignments && var.enable_platform_operator_role && var.pim_enabled ? 1 : 0

  scope              = local.subscription_scope
  role_definition_id = azurerm_role_definition.platform_operator[0].role_definition_resource_id
  principal_id       = local.group_object_ids.platform_operators
  justification      = "Stage 03 group-only Platform Operator eligibility."

  depends_on = [azurerm_role_management_policy.platform_operator]
}

resource "azurerm_pim_eligible_role_assignment" "additional" {
  for_each = var.additional_pim_eligible_role_assignments

  scope              = each.value.scope
  role_definition_id = each.value.role_definition_id
  principal_id       = local.group_object_ids[each.value.group_key]
  justification      = coalesce(each.value.justification, "Stage 03 group-only PIM assignment.")

  dynamic "schedule" {
    for_each = each.value.duration_hours == null ? [] : [each.value.duration_hours]

    content {
      expiration {
        duration_hours = schedule.value
      }
    }
  }

  depends_on = [
    azurerm_role_management_policy.additional,
    terraform_data.input_guard,
  ]
}

resource "azurerm_role_management_policy" "additional" {
  for_each = local.additional_pim_role_policies

  scope              = each.value.scope
  role_definition_id = each.value.role_definition_id

  eligible_assignment_rules {
    expiration_required = false
  }

  active_assignment_rules {
    expiration_required                = true
    expire_after                       = "P90D"
    require_justification              = true
    require_multifactor_authentication = true
  }

  activation_rules {
    maximum_duration                   = var.pim_maximum_duration
    require_approval                   = local.pim_requires_approval
    require_justification              = true
    require_multifactor_authentication = true
    require_ticket_info                = true

    dynamic "approval_stage" {
      for_each = local.pim_requires_approval ? [1] : []

      content {
        primary_approver {
          object_id = local.group_object_ids[var.pim_approval_group_key]
          type      = "Group"
        }
      }
    }
  }

  depends_on = [terraform_data.input_guard]
}
