module "redis" {
  source = "./modules/redis"

  depends_on = [
    azurerm_role_assignment.redis_kv_crypto_user,
  ]  

  config = merge(var.config, {
    identity = {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.redis_uami.id]
    },
    customer_managed_key = merge(
      var.config.customer_managed_key,
      {
        key_vault_key_id        = azurerm_key_vault_key.redis_cmk.id
        user_assigned_identity_id = azurerm_user_assigned_identity.redis_uami.id
      }
    )    
  })
}





