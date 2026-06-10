locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  platform_groups = {
    platform_admins = {
      display_name = "${var.platform_group_prefix}-platform-admins"
      description  = "Privileged platform administrators. Use PIM for standing access."
    }
    platform_operators = {
      display_name = "${var.platform_group_prefix}-platform-operators"
      description  = "Platform operators eligible for the custom Platform Operator role."
    }
    platform_readers = {
      display_name = "${var.platform_group_prefix}-platform-readers"
      description  = "Read-only platform observers and auditors."
    }
  }

  app_team_groups = {
    for name in var.app_team_names : "app_team_${replace(name, "-", "_")}" => {
      display_name = "${var.platform_group_prefix}-app-team-${name}"
      description  = "Application team group for ${name}; used by vending and workload RBAC."
    }
  }

  groups                  = merge(local.platform_groups, local.app_team_groups)
  group_owner_object_ids  = length(var.group_owners_object_ids) > 0 ? var.group_owners_object_ids : [data.azuread_client_config.current.object_id]
  group_object_ids        = { for key, group in azuread_group.this : key => group.object_id }
  valid_group_keys        = keys(local.groups)
  role_assignable_scopes  = length(var.role_assignable_scopes) > 0 ? var.role_assignable_scopes : [local.subscription_scope]
  pim_requires_approval   = var.environment == "prod" && var.pim_require_approval_for_prod
  platform_operator_scope = local.subscription_scope
  platform_operator_role_name = (
    var.platform_operator_role_name != "" ? var.platform_operator_role_name : "Platform Operator - ${var.environment} - ${substr(var.subscription_id, 0, 8)}"
  )

  allowed_active_role_definition_names = [
    "AcrPull",
    "Cost Management Reader",
    "Log Analytics Reader",
    "Monitoring Reader",
    "Reader",
  ]

  additional_pim_role_policy_groups = {
    for _, assignment in var.additional_pim_eligible_role_assignments :
    "${assignment.scope}|${assignment.role_definition_id}" => assignment...
  }
  additional_pim_role_policies = {
    for key, assignments in local.additional_pim_role_policy_groups : key => {
      scope              = assignments[0].scope
      role_definition_id = assignments[0].role_definition_id
    }
  }
}
