terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "ca5258fe-e34d-43ef-bbde-5d1e691ec5c9"
  tenant_id       = "7420ac08-8cd7-41c5-9d81-550653e42014"
}

