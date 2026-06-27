locals {
  resource_group_name  = "rg-pe-tfstate-${var.location_short}"
  storage_account_name = lower("stpetf${var.location_short}${var.name_suffix}")
  key_vault_name       = "kv-pe-boot-${var.location_short}-${var.name_suffix}"
  uami_name            = "id-pe-tfstate-cmk-${var.location_short}"
  cmk_key_name         = "cmk-tfstate-${var.location_short}"
  log_analytics_name   = "log-pe-bootstrap-${var.location_short}"
  action_group_name    = "ag-pe-breakglass-${var.location_short}"

  # Phase 1 firewall allowlist: the persistent break-glass operator ranges plus
  # any ephemeral CI runner IP the bootstrap workflow injects for the duration of
  # a run (TF_VAR_runner_ip_cidrs). Terraform owns and drift-detects the full set
  # so allowed_ip_cidrs is actually enforced; the runner entry is removed again by
  # the workflow's always() cleanup. Replaced by Private Endpoints in connectivity & egress.
  firewall_ip_rules         = distinct(concat(var.allowed_ip_cidrs, var.runner_ip_cidrs))
  local_recovery_ack_phrase = "I understand this temporarily opens bootstrap data planes for local integration or recovery only"
  firewall_allow_permitted = (
    var.local_recovery_mode_enabled &&
    length(var.runner_ip_cidrs) == 0 &&
    var.local_recovery_mode_acknowledgement == local.local_recovery_ack_phrase
  )

  # Mandatory tag taxonomy (plan.md section 10). State holds platform secrets,
  # so it is classified confidential / high confidentiality.
  tags = merge(
    {
      env                = "platform"
      owner              = "platform-engineering"
      costCenter         = var.cost_center
      product            = "landing-zone"
      dataClassification = "confidential"
      confidentiality    = "high"
      managedBy          = "terraform"
      repo               = "${var.github_owner}/${var.github_repo}"
    },
    var.extra_tags,
  )
}
