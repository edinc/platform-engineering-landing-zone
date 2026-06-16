terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }

  # Stage 10 team onboarding state.
  backend "azurerm" {}
}
