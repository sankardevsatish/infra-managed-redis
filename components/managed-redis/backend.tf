terraform {
  backend "azurerm" {
    resource_group_name  = "rg-dev-platform"
    storage_account_name = "terraformstatefileredis"
    container_name       = "tfstate"
    key                  = "managed-redis.tfstate"
  }
}
