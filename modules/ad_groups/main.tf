# resource "azuread_group" "ad_group" {
#   display_name = var.group_name 
#   description  = "Managed by Terraform"
#   security_enabled = true
# }

resource "azuread_group" "ad_group" {
  count    = length(var.group_name)
  display_name     = var.group_name[count.index]
  security_enabled = true
}