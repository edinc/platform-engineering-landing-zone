terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
  }

  # demo profile environment state. Backend settings are supplied at init time
  # via -backend-config (see backend.hcl.example). State access uses Entra ID.
  backend "azurerm" {}
}
