# Custom policy initiatives. The JSON files under policies/azure/initiatives/
# are the source of truth; this stack renders them into
# azurerm_policy_set_definition resources at the alz MG. terraform validate
# evaluates jsondecode(file(...)), so a malformed initiative fails validation
# (and CI), and the policy-test-azure make target adds schema/semantic checks.
locals {
  initiative_files = {
    "tag-baseline"          = "${path.module}/../../../policies/azure/initiatives/tag-baseline.json"
    "private-link-required" = "${path.module}/../../../policies/azure/initiatives/private-link-required.json"
    "aks-baseline"          = "${path.module}/../../../policies/azure/initiatives/aks-baseline.json"
  }

  initiatives = {
    for key, path in local.initiative_files : key => jsondecode(file(path))
  }
}

resource "azurerm_policy_set_definition" "custom" {
  for_each = local.initiatives

  name                = each.value.name
  policy_type         = "Custom"
  display_name        = each.value.displayName
  description         = each.value.description
  management_group_id = local.mg_ids["alz"]
  metadata            = jsonencode(each.value.metadata)
  parameters          = length(try(each.value.parameters, {})) > 0 ? jsonencode(each.value.parameters) : null

  dynamic "policy_definition_group" {
    for_each = try(each.value.policyDefinitionGroups, [])
    content {
      name         = policy_definition_group.value.name
      display_name = try(policy_definition_group.value.displayName, null)
      description  = try(policy_definition_group.value.description, null)
    }
  }

  dynamic "policy_definition_reference" {
    for_each = each.value.policyDefinitions
    content {
      reference_id         = policy_definition_reference.value.policyDefinitionReferenceId
      policy_definition_id = policy_definition_reference.value.policyDefinitionId
      parameter_values     = jsonencode(try(policy_definition_reference.value.parameters, {}))
      policy_group_names   = try(policy_definition_reference.value.groupNames, null)
    }
  }
}

# Stage 02 acceptance criterion 8 (defense in depth alongside policy-test-azure):
# the aks-baseline initiative must NOT install the AKS Policy (Gatekeeper)
# add-on. Kyverno is the single in-cluster admission engine (ADR-0036).
check "aks_baseline_excludes_gatekeeper_addon" {
  assert {
    condition = !contains(
      [for ref in local.initiatives["aks-baseline"].policyDefinitions : ref.policyDefinitionId],
      "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.aks_policy_addon_gatekeeper}"
    )
    error_message = "aks-baseline must NOT include the AKS Policy (Gatekeeper) add-on policy (a8eff44f-8c92-45c3-a3fb-9880802d67a7); Kyverno is the single in-cluster admission engine (ADR-0036, Stage 02 acceptance criterion 8)."
  }
}
