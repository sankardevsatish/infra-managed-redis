terraform {
  backend "azurerm" {
    # These values are passed via -backend-config in the CI/CD pipeline
    # resource_group_name  = "rg-terraform-state"
    # storage_account_name = "stterraformstate"
    # container_name       = "tfstate"
    # key                  = "uksouth/managed-redis/dev/terraform.tfstate"
  }
}
