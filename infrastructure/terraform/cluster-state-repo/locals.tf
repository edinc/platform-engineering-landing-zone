locals {
  seed_source_dir   = abspath("${path.module}/../../../platform-gitops")
  seed_source_files = sort(fileset(local.seed_source_dir, "**/*"))

  legacy_seed_files = {
    "README.md"                          = <<-EOT
      # Platform cluster state

      Flux watches this repository for platform and workload Kubernetes desired
      state. The platform-engineering-landing-zone repository owns the bootstrap
      and templates; this repository owns cluster state.

      ## Layout

      - `clusters/_base/` - shared cluster bases.
      - `clusters/overlays/{demo,nonprod,prod}/` - per-environment overlays.
      - `tenants/` - vended team/workload manifests.
    EOT
    ".github/CODEOWNERS"                 = join("\n", var.codeowners)
    "clusters/_base/.gitkeep"            = ""
    "clusters/overlays/demo/.gitkeep"    = ""
    "clusters/overlays/nonprod/.gitkeep" = ""
    "clusters/overlays/prod/.gitkeep"    = ""
    "tenants/.gitkeep"                   = ""
  }

  stage07_seed_files = merge(
    {
      ".github/CODEOWNERS" = join("\n", var.codeowners)
    },
    {
      for relative_path in local.seed_source_files :
      relative_path => file("${local.seed_source_dir}/${relative_path}")
    },
    {
      for relative_path in sort(fileset("${path.module}/../../../policies/kyverno", "*.yaml")) :
      "clusters/_base/addon-config/policies/kyverno/${relative_path}" => file("${path.module}/../../../policies/kyverno/${relative_path}")
    }
  )

  seed_files = var.stage07_seed_files_enabled ? local.stage07_seed_files : local.legacy_seed_files
}
