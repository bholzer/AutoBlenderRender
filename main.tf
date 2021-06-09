provider "aws" {
  version = "~> 2.31"
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "random_string" "build_id" {
  length = 16
  special = false
  upper = false
  number = false
}

module "network" {
  source = "./modules/network"

  availability_zone = var.availability_zone
  vpc_cidr = var.vpc_cidr
}

module "node_iam_role" {
  source = "./modules/node_iam_role"
}

resource "aws_s3_bucket" "render_bucket" {
  bucket = "${random_string.build_id.result}-render-data"
  acl    = "private"
}

# Stores server-side code bundles. i.e. Worker node and lambda layer
resource "aws_s3_bucket" "code_bundles_bucket" {
  bucket = "${random_string.build_id.result}-code-bundles"
  acl    = "private"
}

# Stores and serves javascript client
resource "aws_s3_bucket" "client_bucket" {
  bucket = "${random_string.build_id.result}-client-bucket"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# Code layer

data "archive_file" "worker_node_code" {
  type = "zip"
  source_dir = "${path.root}/src/lambda_layer"
  output_path = "${path.root}/src/lambda_layer/ruby/lambda_layer.zip""
}

# Code bundles

data "archive_file" "worker_node_code" {
  type = "zip"
  source_dir = "${path.root}/src/farm_worker"
  output_path = "${path.root}/src/bundles/farm_worker.zip"
}

resource "aws_s3_bucket_object" "worker_code_bundle" {
  bucket = aws_s3_bucket.code_bundles_bucket.id
  key = "farm_worker.zip"
  source = "${path.root}/src/bundles/farm_worker.zip"

  depends_on = [data.archive_file.worker_node_code]
}

# Security groups for the worker nodes

resource "aws_security_group" "ssh" {
  name = "allow_ssh"
  vpc_id = module.network.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nfs" {
  name = "NFS"
  vpc_id = module.network.vpc_id

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Build queues for project init and frame rendering

resource "aws_sqs_queue" "frame_render_deadletter" {
  name = "frame_render_deadletter_queue"
}

resource "aws_sqs_queue" "frame_render_queue" {
  name                       = "frame_render_queue"
  visibility_timeout_seconds = 7000
  redrive_policy             = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.frame_render_deadletter.arn}\",\"maxReceiveCount\":5}"
}

resource "aws_sqs_queue" "project_init_queue" {
  name                       = "project_init_queue"
  visibility_timeout_seconds = 7000
}

# EFS for shared storage during baking and rendering

resource "aws_efs_file_system" "shared_render_vol" {

  tags = {
    Name = "SharedRenderEFS"
  }
}

resource "aws_efs_mount_target" "shared_mount" {
  file_system_id = aws_efs_file_system.shared_render_vol.id
  subnet_id      = module.network.subnet_id

  security_groups = [aws_security_group.nfs.id]
}

module "worker_node" {
  source = "./modules/worker_node"

  key_name = var.node_key_name
  image_id = var.blender_node_image_id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.nfs.id]
  iam_instance_profile = module.node_iam_role.worker_iam_profile_name

  build_id = random_string.build_id.result
  region = var.region
  render_bucket = aws_s3_bucket.render_bucket.id
  code_bucket = aws_s3_bucket.code_bundles_bucket.id
  frame_queue_url = aws_sqs_queue.frame_render_queue.id
  project_init_queue_url = aws_sqs_queue.project_init_queue.id
  shared_file_system_id = aws_efs_file_system.shared_render_vol.id

  instance_types = var.instance_types
  asg_name = var.worker_asg_name
  asg_subnets = [module.network.subnet_id]
  asg_max_workers = var.worker_node_max_count
  asg_min_workers = 0
  cloudwatch_namespace = var.cloudwatch_namespace
}

module "bpi_emitter" {
  source = "./modules/bpi_emitter"

  cloudwatch_namespace = var.cloudwatch_namespace
  asg_name = module.worker_node.asg_name
  frame_queue = aws_sqs_queue.frame_render_queue.id
  project_init_queue = aws_sqs_queue.project_init_queue.id
  frame_queue_bpi = var.frame_queue_bpi
  project_init_queue_bpi = var.project_init_queue_bpi
}

# module "bucket_upload_listener" {
#   source = "./modules/bucket_upload_listener"

#   bucket_name = aws_s3_bucket.render_bucket.id
#   bucket_arn = aws_s3_bucket.render_bucket.arn
#   project_init_queue = aws_sqs_queue.project_init_queue.id
# }

resource "aws_dynamodb_table" "projects_table" {
  name = "FarmProjects"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "ProjectId"

  attribute {
    name = "ProjectId"
    type = "S"
  }
}

resource "aws_dynamodb_table" "application_settings" {
  name = "FarmApplicationSettings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "SettingName"

  attribute {
    name = "SettingName"
    type = "S"
  }
}

module "api" {
  source = "./modules/api"

  region = var.region
  bucket = aws_s3_bucket.render_bucket.id
  frame_queue = aws_sqs_queue.frame_render_queue.id
  project_init_queue = aws_sqs_queue.project_init_queue.id
  client_endpoint = "https://${aws_s3_bucket.client_bucket.website_endpoint}"

  dynamo_tables = {
    projects = aws_dynamodb_table.projects_table.name,
    application_settings = aws_dynamodb_table.application_settings.name
  }
}

