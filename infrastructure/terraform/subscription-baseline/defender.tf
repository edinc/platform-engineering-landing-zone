# Microsoft Defender for Cloud plans on the target subscription. Tiers are
# required inputs, not defaults, so applying the stack cannot silently downgrade
# an existing ALZ subscription from Standard coverage to Free.
resource "azurerm_security_center_subscription_pricing" "this" {
  # The Defender tier is operator-configurable per profile via var.defender_tiers.
  # Demo can explicitly set Free for cost; nonprod/prod should set Standard.
  #checkov:skip=CKV_AZURE_19:Tier is an explicit per-profile input (var.defender_tiers); demo may set Free, prod sets Standard (ADR-0011).
  #checkov:skip=CKV_AZURE_55:Defender for Servers tier is an explicit per-profile input; demo may set Free (ADR-0011).
  #checkov:skip=CKV_AZURE_69:Defender for SQL tier is an explicit per-profile input; demo may set Free (ADR-0011).
  #checkov:skip=CKV_AZURE_84:Defender for Storage tier is an explicit per-profile input; demo may set Free (ADR-0011).
  #checkov:skip=CKV_AZURE_87:Defender for Key Vault tier is an explicit per-profile input; demo may set Free (ADR-0011).
  #checkov:skip=CKV_AZURE_234:Defender for Resource Manager tier is an explicit per-profile input; demo may set Free (ADR-0011).
  for_each = local.defender_plans

  tier          = each.value.tier
  resource_type = each.key
  subplan       = each.value.tier == "Standard" ? each.value.subplan : null

  dynamic "extension" {
    for_each = each.value.tier == "Standard" ? each.value.extensions : []

    content {
      name                            = extension.value.name
      additional_extension_properties = extension.value.additional_extension_properties
    }
  }
}
