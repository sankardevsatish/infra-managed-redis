config = {
  name                = "redis-dev-001"
  resource_group_name = "rg-dev-platform"
  location            = "uksouth"
  sku_name            = "Balanced_B0"

  # -------- Core Settings --------
  high_availability_enabled = true
  public_network_access     = "Disabled"

  # -------- Identity (Optional) --------
  identity = {
    type         = "UserAssigned"
    identity_ids = [
      "/subscriptions/ca5258fe-e34d-43ef-bbde-5d1e691ec5c9/resourceGroups/rg-dev-platform/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-redis-dev"
    ]
  }

  # -------- Customer Managed Key (Optional) --------
  customer_managed_key = {
    key_vault_id          = "/subscriptions/ca5258fe-e34d-43ef-bbde-5d1e691ec5c9/resourceGroups/rg-dev-platform/providers/Microsoft.KeyVault/vaults/redis-kv-dev"
    user_assigned_identity_id = "/subscriptions/ca5258fe-e34d-43ef-bbde-5d1e691ec5c9/resourceGroups/rg-dev-platform/providers/Microsoft.ManagedIdentity/userAssignedIdentities/uai-redis-dev"
  }

  # -------- Default Database Config --------
  default_database = {
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "AllKeysLRU"
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
  }

  # -------- Redis Modules (Optional features) --------
#   module = [
#     {
#       name = "RedisJSON"
#     },
#     {
#       name = "RedisSearch"
#     },
#     {
#       name = "RedisBloom"
#       args = ["ERROR_RATE", "0.01", "INITIAL_SIZE", "400"]
#     }
#   ]

  # -------- Tags --------
  tags = {
    environment = "dev"
    owner       = "platform-team"
    managed_by  = "terraform"
    workload    = "redis"
  }
}
