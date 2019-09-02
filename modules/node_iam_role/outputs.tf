output "worker_role_name" {
  value = aws_iam_role.render_node_role.name
}

output "worker_iam_profile_name" {
  value = aws_iam_instance_profile.render_node_profile.name
}