output "gateway_api_id" {
  value = aws_api_gateway_rest_api.farm_api.id
}

output "farm_users_pool_id" {
  value = aws_cognito_user_pool.farm_users_pool.id
}

output "farm_api_client_id" {
  value = aws_cognito_user_pool_client.farm_api_client.id
}
