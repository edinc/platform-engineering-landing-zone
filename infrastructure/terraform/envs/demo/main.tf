locals {
  # Mandatory tag taxonomy (see docs/architecture/README.md). Every resource in the demo
  # composition carries the full set, so a `terraform plan` here is compliant
  # with both the Rego tag gate (policies/rego) and any inherited/reference
  # tag-baseline policy (acceptance criterion 6). env = demo for the demo profile.
  tags = merge(
    {
      env                = "demo"
      owner              = var.owner
      costCenter         = var.cost_center
      product            = "landing-zone"
      dataClassification = "internal"
      confidentiality    = "low"
      managedBy          = "terraform"
      repo               = "${var.github_owner}/${var.github_repo}"
    },
    var.extra_tags,
  )
}

# Representative, policy-compliant demo resource group. Kept intentionally
# minimal (subscription baseline does not deploy demo networking/compute - that starts with connectivity & egress); it exists to prove the demo profile plans clean end to end.
resource "azurerm_resource_group" "demo" {
  name     = "rg-pe-demo-${var.location_short}"
  location = var.location
  tags     = local.tags
}
