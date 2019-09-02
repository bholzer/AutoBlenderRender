resource "aws_api_gateway_rest_api" "farm_api" {
  name = "FarmAPI"
}

resource "aws_api_gateway_deployment" "farm_api_deployment" {
  # An integration exists for each endpoint. Wait on all of them before deplying the API
  depends_on = [
    "module.projects_index_action.integration",
    "module.projects_create_action.integration",
  ]

  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  stage_name  = "prod"
}

resource "aws_api_gateway_resource" "farm_projects" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_rest_api.farm_api.root_resource_id
  path_part   = "projects"
}

module "projects_index_action" {
  source = "../api_action"

  controller = "projects"
  method = "GET"
  action = "index"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.farm_projects
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
}

module "projects_create_action" {
  source = "../api_action"

  controller = "projects"
  method = "POST"
  action = "create"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.farm_projects
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
}
