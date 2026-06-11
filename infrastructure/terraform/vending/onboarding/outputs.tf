output "subscription_id" {
  value       = var.subscription_id
  description = "Externally-created subscription handed to Stage 02."
}

output "subscription_baseline_tfvars_path" {
  value       = local_file.subscription_baseline_tfvars.filename
  description = "Generated tfvars JSON path for infrastructure/terraform/subscription-baseline."
}

output "backend_config_hint" {
  value       = local.backend_config_hint
  description = "Backend settings for the Stage 02 subscription-baseline stack."
}

output "onboarding_evidence" {
  value = {
    management_group_id    = var.management_group_id
    alz_placement_evidence = var.alz_placement_evidence
  }
  description = "Operator evidence proving ALZ placement before Stage 02 baseline."
}
