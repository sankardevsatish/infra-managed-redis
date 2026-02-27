locals {
  standard_tags = {
    ManagedBy   = "Terraform"
    Application = "managed-redis"
  }

  tags = merge(local.standard_tags, try(var.config.tags, {}))
}

