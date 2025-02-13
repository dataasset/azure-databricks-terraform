# output "ad_groups" {
#     value =  {object_id = azuread_group.ad_group.object_id, display_name = azuread_group.ad_group.display_name}
# }


# output "object_id" {
#   value = [for group in azuread_group.ad_group: group.object_id]
# }

output "ad_groups" {
  value       = { for group in azuread_group.ad_group : group.object_id => group.display_name } 
}