provider "azuread" {
  tenant_id = var.tenant_id
}

provider "github" {
  owner = var.github_owner
}
