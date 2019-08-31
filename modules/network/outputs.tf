output "vpc_id" {
  value = aws_vpc.render_farm_vpc.id
}

output "subnet_id" {
  value = aws_subnet.main_subnet.id
}