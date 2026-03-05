data "azurerm_client_config" "current" {}

# Grant the Terraform SP (GitHub Actions) Key Vault Crypto Officer access
# so it can create/manage keys in the Key Vault
resource "azurerm_role_assignment" "terraform_kv_crypto_officer" {
  scope                = var.config.customer_managed_key.key_vault_id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant the Redis UAMI the Crypto Service Encryption User role
resource "azurerm_role_assignment" "redis_kv_crypto_user" {
  scope                = var.config.customer_managed_key.key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.redis_uami.principal_id
}

# Wait for RBAC propagation before creating Redis
# Azure role assignments can take several minutes to become effective
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.redis_kv_crypto_user,
    azurerm_role_assignment.terraform_kv_crypto_officer,
  ]

  create_duration = "300s"
}
