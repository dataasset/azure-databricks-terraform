resource "azurerm_databricks_workspace" "workspace" {
    name = var.resource_name 
    resource_group_name = var.rg_name
    managed_resource_group_name = var.managed_rg_name
    location = var.location
    sku = "premium"
}