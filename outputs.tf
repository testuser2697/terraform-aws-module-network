output "app_subnet_id" {
  value = aws_subnet.subnet["app"].id
}
output "security_group_id" {
  value = aws_security_group.main.id
}

output "module-tags" {
 value = local.mod_tags
 description = "Module tags (teaching aid)."
}