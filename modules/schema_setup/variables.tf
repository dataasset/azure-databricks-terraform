variable "schema_name" {}
variable "catalog_id" {}
variable "principals_and_privileges" {
  description = "List of principals and their privileges"
  type        = list(object({
    name        = string
    privileges  = list(string)
  }))
}