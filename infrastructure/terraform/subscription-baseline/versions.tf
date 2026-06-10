terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
  }

  # Stage 02 subscription-baseline state. Backend settings are supplied at init
  # time via -backend-config (see backend.hcl.example) so no tenant-specific
  # values are committed. State access uses Entra ID (use_azuread_auth = true).
  backend "azurerm" {}
}
