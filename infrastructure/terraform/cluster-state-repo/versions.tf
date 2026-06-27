terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Platform shared services cluster-state repository state. Backend settings are supplied at
  # init time via -backend-config (see backend.hcl.example).
  backend "azurerm" {}
}
