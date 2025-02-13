
output "databricks_host" {
  value = module.workspace.workspace_url
}

output "access_connector_principal_id" {
  value = module.uc_metastore.access_connector_principal_id
}

# output "databricks_account_id" {
#   value = module.workspace.databricks_account_id
# }

# output "databricks_workspace_id" {
#   value = module.workspace.workspace_id
# }


# output "ad_groups" {
#   value = [for group in module.azure_ad_groups: group.ad_groups]
# }



