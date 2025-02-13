output "databricks_host" {
  value = "https://${azurerm_databricks_workspace.workspace.workspace_url}/"
}

output "workspace_url" {
  value = azurerm_databricks_workspace.workspace.workspace_url
}

output "workspace_id" {
  value = azurerm_databricks_workspace.workspace.workspace_id
}

output "workspace_name" {
  value = azurerm_databricks_workspace.workspace.name
}

output "databricks_account_id" {
  value = azurerm_databricks_workspace.workspace.id
}