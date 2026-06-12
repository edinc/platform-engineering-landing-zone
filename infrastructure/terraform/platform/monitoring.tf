locals {
  alerting_severity_config = {
    sev1 = {
      short_name  = "pe-sev1"
      receiver    = "PagerDuty SEV1"
      description = "Pages the on-call engineer for user-visible platform outages."
    }
    sev2 = {
      short_name  = "pe-sev2"
      receiver    = "PagerDuty SEV2"
      description = "Creates an incident/ticket for degraded platform behavior."
    }
    sev3 = {
      short_name  = "pe-sev3"
      receiver    = "Platform digest"
      description = "Routes low-urgency alerts to a digest channel."
    }
  }
}

resource "azurerm_monitor_action_group" "stage08" {
  for_each = var.enable_alerting_action_groups ? local.alerting_severity_config : {}

  name                = local.action_group_name[each.key]
  resource_group_name = azurerm_resource_group.platform.name
  short_name          = each.value.short_name
  enabled             = true
  tags                = local.tags

  dynamic "webhook_receiver" {
    for_each = var.profile == "demo" ? [var.alerting_teams_webhook_url] : []

    content {
      name                    = "Teams ${upper(each.key)}"
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "itsm_receiver" {
    for_each = var.profile != "demo" && var.alerting_pagerduty_itsm != null ? [var.alerting_pagerduty_itsm] : []

    content {
      name                 = each.value.receiver
      workspace_id         = itsm_receiver.value.workspace_id
      connection_id        = itsm_receiver.value.connection_id
      region               = itsm_receiver.value.region
      ticket_configuration = itsm_receiver.value.ticket_configuration
    }
  }

  dynamic "email_receiver" {
    for_each = var.alerting_email_receivers

    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "platform_slos" {
  count = var.enable_alerting_action_groups && var.enable_aks ? 1 : 0

  name                = "amprg-${local.name_prefix}-platform-slos"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  cluster_name        = azurerm_kubernetes_cluster.platform[0].name
  description         = "Stage 08 platform SLO alert rules routed through Azure Monitor Action Groups."
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [var.azure_monitor_workspace_id]
  tags                = local.tags

  rule {
    alert      = "FluxReconciliationP95Slow"
    enabled    = true
    expression = "histogram_quantile(0.95, sum by (le) (rate(gotk_reconcile_duration_seconds_bucket[5m]))) > 300"
    for        = "PT15M"
    severity   = 2

    action {
      action_group_id = azurerm_monitor_action_group.stage08["sev2"].id
    }

    annotations = {
      runbook_url = "docs/runbooks/sre/flux-reconciliation-latency.md"
      summary     = "Flux reconciliation p95 latency is above five minutes."
    }

    labels = {
      route = "ticket"
    }
  }

  rule {
    alert      = "ClusterApiAvailabilityBurn"
    enabled    = true
    expression = "sum(rate(apiserver_request_total{code=~\"5..\"}[5m])) / sum(rate(apiserver_request_total[5m])) > 0.001"
    for        = "PT10M"
    severity   = 1

    action {
      action_group_id = azurerm_monitor_action_group.stage08["sev1"].id
    }

    annotations = {
      runbook_url = "docs/runbooks/sre/cluster-api-availability.md"
      summary     = "AKS API server error budget is burning too quickly."
    }

    labels = {
      route = "pagerduty"
    }
  }

  rule {
    alert      = "KyvernoSignatureVerifyOverheadHigh"
    enabled    = true
    expression = "sum(rate(kyverno_admission_review_duration_seconds_sum{policy_name=\"verify-cosign-signatures\"}[5m])) / sum(rate(kyverno_admission_review_duration_seconds_count{policy_name=\"verify-cosign-signatures\"}[5m])) > 0.2"
    for        = "PT20M"
    severity   = 3

    action {
      action_group_id = azurerm_monitor_action_group.stage08["sev3"].id
    }

    annotations = {
      runbook_url = "docs/runbooks/sre/platform-slo-burn.md"
      summary     = "Kyverno signature verification mean overhead is above the 200 ms platform target."
    }

    labels = {
      route = "digest"
    }
  }
}
