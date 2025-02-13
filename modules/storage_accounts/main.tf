resource "azurerm_storage_account" "storage_account" {
  name                     = var.resource_name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}