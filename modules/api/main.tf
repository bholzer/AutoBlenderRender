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
    "module.bake_tasks_create_action.integration"
  ]

  rest_api_id = aws_api_gateway_rest_api.farm_api.id
  stage_name  = "prod"
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
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
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
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}

module "project_show_action" {
  source = "../api_action"

  controller = "projects"
  method = "GET"
  action = "show"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.farm_project
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}


module "project_blendfile_uploader" {
  source = "../api_action"

  controller = "projects"
  method = "GET"
  action = "blendfile_uploader"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.blendfile_uploader
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}

module "render_tasks_create_action" {
  source = "../api_action"

  controller = "render_tasks"
  method = "POST"
  action = "create"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.render_tasks
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}

module "render_tasks_index_action" {
  source = "../api_action"

  controller = "render_tasks"
  method = "GET"
  action = "index"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.render_tasks
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}

module "render_task_show_action" {
  source = "../api_action"

  controller = "render_tasks"
  method = "GET"
  action = "show"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.render_task
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}

module "bake_tasks_create_action" {
  source = "../api_action"

  controller = "bake_tasks"
  method = "POST"
  action = "create"
  rest_api = aws_api_gateway_rest_api.farm_api
  api_resource = aws_api_gateway_resource.bake_tasks
  deployment = aws_api_gateway_deployment.farm_api_deployment
  region = var.region
  dynamo_tables = var.dynamo_tables
  bucket = var.bucket
  frame_queue = var.frame_queue
  project_init_queue = var.project_init_queue
}
