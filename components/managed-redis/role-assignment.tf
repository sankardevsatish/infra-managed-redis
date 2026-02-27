resource "azurerm_role_assignment" "redis_kv_crypto_user" {
  scope                = var.config.customer_managed_key.key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.redis_uami.principal_id
}
