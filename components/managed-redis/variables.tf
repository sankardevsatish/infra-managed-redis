variable "config" {
  description = "Managed Redis config passed to the child module"
  type = object({
    name                = string
    resource_group_name = string
    location            = string
    sku_name            = string

    high_availability_enabled = optional(bool, true)
    public_network_access     = optional(string, "Enabled")

    identity = optional(object({
      type         = string
      identity_ids = optional(list(string), [])
    }))

    customer_managed_key = optional(object({
      key_vault_id              = string    
      key_vault_key_id          = optional(string)
      user_assigned_identity_id = string
    }))

    default_database = optional(object({
      geo_replication_group_name         = optional(string)
      clustering_policy                  = optional(string)
      eviction_policy                    = optional(string)
      access_keys_authentication_enabled = optional(bool)
      client_protocol                    = optional(string)
    }))

    # module = optional(list(object({
    #   name = string
    #   args = optional(list(string), [])
    # })), [])

    tags = optional(map(string), {})
  })
}

