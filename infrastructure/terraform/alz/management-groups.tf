# ALZ management-group hierarchy. Azure requires a parent management group to
# exist before its children. A single self-referencing for_each resource
# (azurerm_management_group.this[each.value.parent].id read inside the same
# resource) is NOT a valid way to express that: it passes terraform validate but
# deadlocks terraform plan with "Error: Cycle", because Terraform builds the
# dependency at the whole-resource level. We therefore materialise the hierarchy
# as one resource per depth tier; each tier references the tier ABOVE for its
# parent ID, which gives a correct parent-before-child ordering with no
# self-reference. The stage-02 hierarchy is exactly three tiers deep
# (root -> alz -> {platform,landingzones,...} -> {management,connectivity,...}).
# Adding a deeper node requires a new tier resource; terraform_data.mg_guard
# fails the plan if anything is nested deeper than tier 2 or names an unknown
# parent.
#
# MG move blast radius: associating a subscription, or re-parenting a node,
# re-evaluates every inherited policy assignment against the new ancestry. Treat
# any change here as a security-reviewed change (brownfield runbook).

# Hard guard: fail the plan (a check block would only warn) when the hierarchy
# cannot be represented by the three tier resources below.
resource "terraform_data" "mg_guard" {
  input = local.mg_depth

  lifecycle {
    precondition {
      condition = alltrue([
        for k, v in local.management_groups :
        v.parent == null || contains(keys(local.management_groups), v.parent)
      ])
      error_message = "A management group in local.management_groups names a parent key that does not exist."
    }
    precondition {
      condition     = alltrue([for k, d in local.mg_depth : d <= 2])
      error_message = "A management group is nested deeper than the supported 3 tiers; add an explicit tier resource in management-groups.tf."
    }
  }
}

# Tier 0: top-level MGs hanging off root_parent_id (the Tenant Root Group by
# default).
resource "azurerm_management_group" "root" {
  for_each = local.mg_tier0

  name         = "${var.management_group_prefix}${each.key}"
  display_name = each.value.display_name

  parent_management_group_id = local.root_parent_id
}

# Tier 1: children of a tier-0 MG.
resource "azurerm_management_group" "level1" {
  for_each = local.mg_tier1

  name         = "${var.management_group_prefix}${each.key}"
  display_name = each.value.display_name

  parent_management_group_id = azurerm_management_group.root[each.value.parent].id
}

# Tier 2: children of a tier-1 MG.
resource "azurerm_management_group" "level2" {
  for_each = local.mg_tier2

  name         = "${var.management_group_prefix}${each.key}"
  display_name = each.value.display_name

  parent_management_group_id = azurerm_management_group.level1[each.value.parent].id
}

# Optional, brownfield-safe subscription placement. Only created for MGs that
# were given a subscription ID. Destroying an association moves the subscription
# back to the Tenant Root Group, which drops MG-inherited assignments from it.
resource "azurerm_management_group_subscription_association" "this" {
  for_each = local.subscription_associations

  management_group_id = local.mg_ids[each.key]
  subscription_id     = "/subscriptions/${each.value}"
}
