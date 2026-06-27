resource "terraform_data" "input_guard" {
  input = {
    subscription_id        = var.subscription_id
    management_group_id    = var.management_group_id
    alz_placement_evidence = var.alz_placement_evidence
  }

  lifecycle {
    precondition {
      condition     = var.monthly_budget_amount == null || (var.budget_start_date != "" && length(var.budget_contact_emails) > 0)
      error_message = "monthly_budget_amount requires budget_start_date and budget_contact_emails for the subscription baseline."
    }
  }
}

resource "local_file" "subscription_baseline_tfvars" {
  filename             = "${path.module}/${var.output_directory}/subscription-baseline.auto.tfvars.json"
  content              = jsonencode(local.subscription_baseline_tfvars)
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [terraform_data.input_guard]
}

resource "local_file" "handoff" {
  filename = "${path.module}/${var.output_directory}/handoff.json"
  content = jsonencode({
    subscription_id        = var.subscription_id
    management_group_id    = var.management_group_id
    alz_placement_evidence = var.alz_placement_evidence
    backend_config_hint    = local.backend_config_hint
  })
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [terraform_data.input_guard]
}
