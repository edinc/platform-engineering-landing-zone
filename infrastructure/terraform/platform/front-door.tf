resource "azurerm_cdn_frontdoor_profile" "platform" {
  count = var.enable_front_door ? 1 : 0

  name                     = "afd-${local.name_prefix}"
  resource_group_name      = azurerm_resource_group.platform.name
  sku_name                 = "Premium_AzureFrontDoor"
  response_timeout_seconds = 120
  tags                     = local.tags

  log_scrubbing_rule {
    match_variable = "RequestIPAddress"
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "platform" {
  count = var.enable_front_door ? 1 : 0

  name                = "wafpe${var.profile}${var.location_short}${var.name_suffix}"
  resource_group_name = azurerm_resource_group.platform.name
  sku_name            = azurerm_cdn_frontdoor_profile.platform[0].sku_name
  enabled             = true
  mode                = "Detection"
  tags                = local.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Log"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Log"
  }
}
