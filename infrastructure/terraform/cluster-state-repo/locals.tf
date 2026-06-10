locals {
  seed_files = {
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
}
