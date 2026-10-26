output "app_subnet_id" {
  value = aws_subnet.subnet["app"].id
}
output "security_group_id" {
  value = aws_security_group.main.id
}

output "module_version" {
  description = "Version of the network module"
  value       = terraform_data.module_version.output.version
}
