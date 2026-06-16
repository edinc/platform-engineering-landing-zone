resource "terraform_data" "input_guard" {
  input = {
    repository_profile              = var.repository_profile
    enable_branch_protection        = var.enable_branch_protection
    branch_protection_bypass_reason = var.branch_protection_bypass_reason
  }

  lifecycle {
    precondition {
      condition = (
        var.enable_branch_protection ||
        (
          var.repository_profile == "demo" &&
          length(trimspace(var.branch_protection_bypass_reason)) >= 16
        )
      )
      error_message = "enable_branch_protection may be false only for demo integration repositories with a non-empty branch_protection_bypass_reason."
    }
  }
}

resource "github_repository" "cluster_state" {
  #checkov:skip=CKV_GIT_3:Vulnerability alerts are enabled via github_repository_vulnerability_alerts because the inline argument is deprecated in provider v6.
  name                   = var.repository_name
  description            = "Flux source of truth for platform cluster state."
  visibility             = var.repository_visibility
  has_issues             = true
  has_projects           = false
  has_wiki               = false
  delete_branch_on_merge = true
  auto_init              = true
}

resource "github_repository_vulnerability_alerts" "cluster_state" {
  repository = github_repository.cluster_state.name
}

resource "github_branch_default" "cluster_state" {
  repository = github_repository.cluster_state.name
  branch     = var.default_branch
}

resource "github_repository_file" "seed" {
  for_each = local.seed_files

  repository          = github_repository.cluster_state.name
  branch              = github_branch_default.cluster_state.branch
  file                = each.key
  content             = each.value
  commit_message      = "chore: seed platform cluster state layout"
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content,
      commit_message,
    ]
  }
}

resource "github_branch_protection" "main" {
  count = var.enable_branch_protection ? 1 : 0

  repository_id  = github_repository.cluster_state.node_id
  pattern        = var.default_branch
  enforce_admins = true

  required_pull_request_reviews {
    required_approving_review_count = 2
    require_code_owner_reviews      = true
  }

  require_signed_commits = true

  dynamic "required_status_checks" {
    for_each = length(var.required_status_checks) > 0 ? [var.required_status_checks] : []

    content {
      strict   = true
      contexts = required_status_checks.value
    }
  }

  depends_on = [github_repository_file.seed]
}

moved {
  from = github_branch_protection.main
  to   = github_branch_protection.main[0]
}
