terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Phase 1 backend: AzureRM remote state in the bootstrap-created storage
  # account. Backend settings are supplied at init time via -backend-config
  # (see backend.hcl.example) so no tenant-specific values are committed.
  # State access uses Entra ID (use_azuread_auth = true); no storage keys.
  backend "azurerm" {}
}
