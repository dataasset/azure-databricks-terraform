# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

# provider "databricks" {
#   host = azurerm_databricks_workspace.db_workspace.workspace_url
# }