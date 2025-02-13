resource "databricks_external_location" "location" {
    name = var.external_location_name
    url = format("abfss://%s@%s.dfs.core.windows.net",var.storage_container_name,var.storage_account_name)
    credential_name = var.storage_credential_id
    comment = "External location used by dev catalog as root storage"
}


resource "databricks_catalog" "catalog_name" {
    metastore_id = var.metastore_id 
    name = var.catalog_name
    storage_root = databricks_external_location.location.url
    depends_on = [databricks_external_location.location]
}

resource "databricks_grants" "grants" {
    catalog = databricks_catalog.catalog_name.name
    dynamic "grant" {
        for_each = var.principals_and_privileges
        content {
            principal  = grant.value.name
            privileges = grant.value.privileges
            }
        }
}