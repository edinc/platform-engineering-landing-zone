# Microsoft Defender for Cloud plans on the management subscription. This is the
# provider subscription, so these pricing resources apply to it and surface a
# Secure Score there (acceptance criterion 4). Platform-MG-wide Defender enablement
# is a future DeployIfNotExists rollout; per-subscription pricing is set as
# subscriptions are vended.
#
# Plans that require a subplan (Servers P2, APIs P1, Storage DefenderForStorageV2)
# carry it only when enabled (Standard); a subplan is invalid with the Free tier.
resource "azurerm_security_center_subscription_pricing" "this" {
  # The Defender tier is operator-configurable per profile via var.defender_tiers.
  # The demo profile defaults to Free for cost (ADR-0011 criterion 4); nonprod/prod
  # set Standard. Checkov cannot resolve the per-environment tier, so these
  # tier/plan checks are skipped here and governed by the profile tfvars instead.
  #checkov:skip=CKV_AZURE_19:Tier is per-profile configurable (var.defender_tiers); demo defaults to Free for cost, prod sets Standard (ADR-0011).
  #checkov:skip=CKV_AZURE_55:Defender for Servers tier is set per profile via var.defender_tiers; demo defaults to Free (ADR-0011).
  #checkov:skip=CKV_AZURE_69:Defender for SQL tier is set per profile via var.defender_tiers; demo defaults to Free (ADR-0011).
  #checkov:skip=CKV_AZURE_84:Defender for Storage tier is set per profile via var.defender_tiers; demo defaults to Free (ADR-0011).
  #checkov:skip=CKV_AZURE_87:Defender for Key Vault tier is set per profile via var.defender_tiers; demo defaults to Free (ADR-0011).
  for_each = local.defender_plans

  tier          = each.value.tier
  resource_type = each.key
  subplan       = each.value.tier == "Standard" ? each.value.subplan : null
}
