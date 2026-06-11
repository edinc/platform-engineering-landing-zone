terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
  }

  # Stage 05 subscription vending state. Backend settings are supplied at init
  # time via -backend-config so tenant-specific values are not committed.
  backend "azurerm" {}
}
