resource "azurerm_resource_group" "main" {
  name = "${var.prefix}-${var.environment}-${var.location}-workload-rg"
  location = var.location  
}

resource "azurerm_static_site" "main" {
  name = "${var.prefix}-${var.environment}-${var.location}-swa"
  resource_group_name = azurerm_resource_group.main.name
  location = "westus2" # australiaeast is not supported
}