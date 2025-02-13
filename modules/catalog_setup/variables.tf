variable "external_location_name" {}
variable "storage_container_name" {}
variable "storage_account_name" {}
variable "storage_credential_id" {}
variable "metastore_id" {}
variable "catalog_name" {}
variable "principals_and_privileges" {
  description = "List of principals and their privileges"
  type        = list(object({
    name        = string
    privileges  = list(string)
  }))
}