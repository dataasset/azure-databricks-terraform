resource "azurerm_databricks_access_connector" "access_connector" {
    name = var.access_connector_name
    resource_group_name = var.resource_group_name
    location = var.resource_group_location
    identity {
        type = "SystemAssigned"
    }
}

// Assign the Storage Blob Data Contributor role to managed identity to allow unity catalog to access the storage
resource "azurerm_role_assignment" "mi_data_contributor" {
    scope = var.catalog_id
    role_definition_name = "Storage Blob Data Contributor"
    principal_id = azurerm_databricks_access_connector.access_connector.identity[0].principal_id
}

resource "databricks_metastore" "databricks-metastore" {
    name = var.metastore_name
    storage_root = format("abfss://%s@%s.dfs.core.windows.net/", var.container_name, var.storage_account_name)
    force_destroy = true
    region = var.resource_group_location
}

resource "databricks_metastore_data_access" "access-connector-data-access" { 
  metastore_id = databricks_metastore.databricks-metastore.id
  name = var.access_connector_name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.access_connector.id
  }
  is_default = true
}

resource "databricks_metastore_assignment" "this" {
  workspace_id = var.workspace_id
  metastore_id = databricks_metastore.databricks-metastore.id
  default_catalog_name = "hive_metastore"
}