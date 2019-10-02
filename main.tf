provider "aws" {
  version = "~> 2.0"
  region = var.region
}

data "aws_caller_identity" "current" {}

module "network" {
  source = "./modules/network"

  availability_zone = var.availability_zone
  vpc_cidr = var.vpc_cidr
}

module "node_iam_role" {
  source = "./modules/node_iam_role"
}

resource "random_string" "random_render_bucket_name" {
  length = 16
  special = false
  number = false
}

resource "random_string" "random_client_bucket_name" {
  length = 16
  special = false
  number = false
}

resource "aws_s3_bucket" "render_bucket" {
  bucket = var.render_bucket_name != "" ? random_string.random_render_bucket_name.result : var.render_bucket_name
  acl    = "private"
}

resource "aws_s3_bucket" "client_bucket" {
  bucket = "client-bucket123123"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
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
  user_data = base64encode(templatefile("./node_scripts/user_data.tmpl", {
    init_script = file("./node_scripts/farm_worker.rb"),
    blender_bake_smoke = file("./node_scripts/blender_scripts/bake_smoke.py"),
    region = var.region,
    bucket = aws_s3_bucket.render_bucket.id,
    frame_queue_url = aws_sqs_queue.frame_render_queue.id,
    project_init_queue_url = aws_sqs_queue.project_init_queue.id,
    asg_name = var.worker_asg_name,
    shared_file_system_id = aws_efs_file_system.shared_render_vol.id
  }))

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

