resource "azurerm_user_assigned_identity" "redis_uami" {
  name                = "${var.config.name}-uami"
  resource_group_name = var.config.resource_group_name
  location            = var.config.location
  tags                = var.config.tags
}
