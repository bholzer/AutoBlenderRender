provider "aws" {
  version = "~> 2.0"
  region = var.region
}

# Package the lambda functions
data "archive_file" "bpi_lambda_zip" {
  type = "zip"
  source_dir = "./lambdas/bpi_metric_emitter"
  output_path = "./lambdas/bpi_metric_emitter.zip"
}

data "archive_file" "s3_upload_handler" {
  type = "zip"
  source_dir = "./lambdas/s3_upload_handler"
  output_path = "./lambdas/s3_upload_handler.zip"
}

module "network" {
  source = "./modules/network"

  availability_zone = var.availability_zone
  vpc_cidr = var.vpc_cidr
}

module "node_iam_role" {
  source = "./modules/node_iam_role"
}

# Bucket for uploading blends and storing render output

resource "aws_s3_bucket" "render_bucket" {
  bucket = var.render_bucket_name
  acl    = "private"
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

resource "aws_iam_instance_profile" "render_node_profile" {
  name = "render_node_profile"
  role = module.node_iam_role.name
}

# Launch templates for worker types

resource "aws_launch_template" "worker_node_template" {
  name = "worker_node_template"
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 10
    }
  }

  key_name = var.node_key_name

  image_id = var.blender_node_image_id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.nfs.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.render_node_profile.name
  }

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
}

resource "aws_autoscaling_group" "worker_nodes" {
  name = var.worker_asg_name
  vpc_zone_identifier = [module.network.subnet_id]
  max_size = var.worker_node_max_count
  min_size = 0

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.worker_node_template.id
        version = "$Latest"
      }

      override {
        instance_type = "c5.9xlarge"
      }

      override {
        instance_type = "c4.8xlarge"
      }

      override {
        instance_type = "c5n.9xlarge"
      }

      override {
        instance_type = "c5.4xlarge"
      }
    }
    instances_distribution {
      spot_instance_pools = 4
      on_demand_percentage_above_base_capacity = 10
    }
  }
}

resource "aws_autoscaling_policy" "worker_node_autoscaling_policy" {
  name = "worker_node_autoscaling_policy"
  adjustment_type = "PercentChangeInCapacity"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.worker_nodes.name

  target_tracking_configuration {
    target_value = 2
    customized_metric_specification {
      metric_dimension {
        name = "Queue"
        value = aws_autoscaling_group.worker_nodes.name
      }

      metric_name = "BacklogPerInstance"
      namespace = var.cloudwatch_namespace
      statistic = "Average"
      unit = "None"
    }
  }
}

# Setup BPI metric emitter and listener

resource "aws_cloudwatch_event_rule" "bpi_trigger" {
  name        = "BacklogPerInstanceMetricTrigger"
  description = "Every minute, hit lambda to check the queues and emit a BPI metric"

  schedule_expression = "rate(1 minute)"
}

resource "aws_iam_role" "bpi_metric_emitter_role" {
  name = "bpi_metric_emitter_role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "autoscale_bpi_metric_emitter_attach_policy" {
  role = aws_iam_role.bpi_metric_emitter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_bpi_metric_emitter_attach_policy" {
  role = aws_iam_role.bpi_metric_emitter_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "sqs_bpi_metric_emitter_attach_policy" {
  role = aws_iam_role.bpi_metric_emitter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_bpi_metric_emitter_attach_policy" {
  role = aws_iam_role.bpi_metric_emitter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


resource "aws_lambda_function" "bpi_metric_emitter" {
  filename = "./lambdas/bpi_metric_emitter.zip"
  function_name = "bpi_metric_emitter"
  role = aws_iam_role.bpi_metric_emitter_role.arn
  handler = "bpi_metric_emitter.lambda_handler"
  runtime = "ruby2.5"

  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = var.cloudwatch_namespace
      ASG_NAME = aws_autoscaling_group.worker_nodes.name
      FRAME_QUEUE = aws_sqs_queue.frame_render_queue.id
      FRAME_QUEUE_BPI = var.frame_queue_bpi
      PROJECT_INIT_QUEUE = aws_sqs_queue.project_init_queue.id
      PROJECT_INIT_QUEUE_BPI = var.project_init_queue_bpi
    }
  }
}

resource "aws_cloudwatch_event_target" "bpi_metric_emitter_cw_target" {
  target_id = "bpi_metric_emitter_cw_target"
  rule = aws_cloudwatch_event_rule.bpi_trigger.name
  arn = aws_lambda_function.bpi_metric_emitter.arn
}

resource "aws_lambda_permission" "bpi_metric_emitter_cw_trigger_permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bpi_metric_emitter.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.bpi_trigger.arn
}

# S3 project upload listener

resource "aws_iam_role" "s3_upload_handler_role" {
  name = "s3_upload_handler_role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_upload_handler_lambda_execution_role" {
  name = "s3_upload_lambda_execution_role"
  path = "/"
  description = "Lambda Execution Policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sqs_s3_upload_handler_attach_policy" {
  role = aws_iam_role.s3_upload_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_s3_upload_handler_attach_policy" {
  role = aws_iam_role.s3_upload_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_upload_handler_attach_policy" {
  role = aws_iam_role.s3_upload_handler_role.name
  policy_arn = aws_iam_policy.s3_upload_handler_lambda_execution_role.arn
}

resource "aws_lambda_function" "s3_upload_handler" {
  filename = "./lambdas/s3_upload_handler.zip"
  function_name = "s3_upload_handler"
  role = aws_iam_role.s3_upload_handler_role.arn
  handler = "s3_upload_handler.lambda_handler"
  runtime = "ruby2.5"

  environment {
    variables = {
      BUCKET = aws_s3_bucket.render_bucket.id
      PROJECT_INIT_QUEUE = aws_sqs_queue.project_init_queue.id
    }
  }
}

resource "aws_s3_bucket_notification" "blend_upload_notification" {
  bucket = aws_s3_bucket.render_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_upload_handler.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".blend"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_upload_handler.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".tar.gz"
  }
}

resource "aws_lambda_permission" "s3_upload_handler_trigger_permission" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_upload_handler.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.render_bucket.arn
}

