resource "aws_api_gateway_rest_api" "farm_api" {
  name = "FarmAPI"
}

resource "aws_api_gateway_deployment" "farm_api_deployment" {
  # An integration exists for each endpoint. Wait on all of them before deplying the API
  depends_on = [
    "module.projects_index_action.integration",
    "module.projects_create_action.integration",
    "module.project_show_action.integration",
    "module.project_blendfile_uploader.integration",
    "module.render_tasks_create_action.integration",
    "module.render_tasks_index_action.integration",
    "module.render_task_show_action.integration",
    "module.bake_tasks_create_action.integration"
  ]

  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  stage_name  = "prod"
}

resource "aws_lambda_layer_version" "api_lambda_layer" {
  filename   = "${path.root}/src/lambda_layer/lambda_layer.zip"
  layer_name = "api_layer"

  compatible_runtimes = ["ruby2.5"]
}

resource "aws_cognito_user_pool" "farm_users_pool" {
  name = "farm_users"
}

resource "aws_cognito_user_pool_client" "farm_api_client" {
  name = "farm_api_client"

  user_pool_id = aws_cognito_user_pool.farm_users_pool.id
  callback_urls = [var.client_endpoint]
  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
}

resource "random_string" "random_domain" {
  length = 16
  special = false
}

resource "aws_cognito_user_pool_domain" "farm_users_pool_domain" {
  domain       = "fupdomain"
  user_pool_id = aws_cognito_user_pool.farm_users_pool.id
}

resource "aws_api_gateway_authorizer" "farm_api_authorizer" {
  name                   = "farm_api_authorizer"
  rest_api_id            = aws_api_gateway_rest_api.farm_api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [aws_cognito_user_pool.farm_users_pool.arn]
}

resource "aws_api_gateway_resource" "farm_projects" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_rest_api.farm_api.root_resource_id
  path_part   = "projects"
}

resource "aws_api_gateway_resource" "farm_project" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_resource.farm_projects.id
  path_part   = "{project_id}"
}

resource "aws_api_gateway_resource" "bake_tasks" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_resource.farm_project.id
  path_part   = "bake_tasks"
}

resource "aws_api_gateway_resource" "render_tasks" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_resource.farm_project.id
  path_part   = "render_tasks"
}

resource "aws_api_gateway_resource" "render_task" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_resource.render_tasks.id
  path_part   = "{render_task_id}"
}

resource "aws_api_gateway_resource" "blendfile_uploader" {
  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  parent_id   = aws_api_gateway_resource.farm_project.id
  path_part   = "blendfile_uploader"
}

module "api_endpoint" {
  for_each = {
    projects_index = {
      controller = "projects"
      method = "GET"
      action = "index"
      resource = aws_api_gateway_resource.farm_projects
    }
    projects_create = {
      controller = "projects"
      method = "POST"
      action = "create"
      resource = aws_api_gateway_resource.farm_projects
    }
    project_show = {
      controller = "projects"
      method = "GET"
      action = "show"
      resource = aws_api_gateway_resource.farm_project
    }
    project_destroy = {
      controller = "projects"
      method = "DELETE"
      action = "destroy"
      resource = aws_api_gateway_resource.farm_project
    }
    project_blendfile_uploader = {
      controller = "projects"
      method = "GET"
      action = "blendfile_uploader"
      resource = aws_api_gateway_resource.blendfile_uploader
    }
    render_tasks_create = {
      controller = "render_tasks"
      method = "POST"
      action = "create"
      resource = aws_api_gateway_resource.render_tasks
    }
    render_tasks_index = {
      controller = "render_tasks"
      method = "GET"
      action = "index"
      resource = aws_api_gateway_resource.render_tasks
    }
    render_task_show = {
      controller = "render_tasks"
      method = "GET"
      action = "show"
      resource = aws_api_gateway_resource.render_task
    }
    bake_tasks_create = {
      controller = "bake_tasks"
      method = "POST"
      action = "create"
      resource = aws_api_gateway_resource.bake_tasks
    }
  }

  source = "../api_action"

  controller = lookup(each.value, "controller")
  method = lookup(each.value, "method")
  action = lookup(each.value, "action")
  api_resource = lookup(each.value, "resource")

  api_lambda_layer = aws_lambda_layer_version.api_lambda_layer.arn
  rest_api = aws_api_gateway_rest_api.farm_api
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.farm_api_authorizer.id
}
