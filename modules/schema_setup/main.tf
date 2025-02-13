resource "databricks_schema" "schema" {
    catalog_name =  var.catalog_id
    name = var.schema_name
}

resource "databricks_grants" "grants" {
    schema = databricks_schema.schema.id
    dynamic "grant" {
        for_each = var.principals_and_privileges
        content {
            principal  = grant.value.name
            privileges = grant.value.privileges
            }
        }
    depends_on = [databricks_schema.schema]
}