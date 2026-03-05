resource "azurerm_key_vault_key" "redis_cmk" {
  name         = "redis-cmk-key"
  key_vault_id = var.config.customer_managed_key.key_vault_id

  key_type = "RSA"
  key_size = 2048

  key_opts = [
    "encrypt",
    "decrypt",
    "wrapKey",
    "unwrapKey",
    "sign",
    "verify"
  ]

  depends_on = [
    azurerm_role_assignment.terraform_kv_crypto_officer,
  ]
}
