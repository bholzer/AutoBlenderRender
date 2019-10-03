resource "aws_launch_template" "worker_node_template" {
  name = "worker_node_template"
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 10
    }
  }

  key_name = var.key_name

  image_id = var.image_id
  vpc_security_group_ids = var.vpc_security_group_ids

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  user_data = base64encode(templatefile("${path.module}/user_data.tmpl", {
    region = var.region
    render_bucket = var.render_bucket
    code_bucket = var.code_bucket
    frame_queue_url = var.frame_queue_url
    project_init_queue_url = var.project_init_queue_url
    asg_name = var.asg_name
    shared_file_system_id = var.shared_file_system_id
  }))
}

resource "aws_autoscaling_group" "worker_nodes" {
  name = var.asg_name
  vpc_zone_identifier = var.asg_subnets
  max_size = var.asg_max_workers
  min_size = var.asg_min_workers

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.worker_node_template.id
        version = "$Latest"
      }

      dynamic "override" {
        for_each = [for it in var.instance_types: {instance_type = it}]

        content {
          instance_type = override.value.instance_type
        }
      }
    }
    instances_distribution {
      spot_instance_pools = length(var.instance_types)
      on_demand_percentage_above_base_capacity = 10
    }
  }
}

# autoscaling policy to handle the starting/stopping of the ASG
# resource "aws_autoscaling_policy" "worker_node_scale_out" {
#   name = "worker_node_scale_out"
#   adjustment_type = "PercentChangeInCapacity"
#   policy_type = "StepScaling"
#   autoscaling_group_name = aws_autoscaling_group.worker_nodes.name

#   step_adjustment {
#     scaling_adjustment = 25
#     metric_interval_lower_bound = 0
#   }

#   step_adjustment {
#     scaling_adjustment = -25
#     metric_interval_upper_bound = 0
#   }
# }

# resource "aws_autoscaling_policy" "worker_node_scale_in" {
#   name = "worker_node_scale_in"
#   adjustment_type = "PercentChangeInCapacity"
#   policy_type = "StepScaling"
#   autoscaling_group_name = aws_autoscaling_group.worker_nodes.name

#   step_adjustment {
#     scaling_adjustment = 25
#     metric_interval_lower_bound = 0
#   }

#   step_adjustment {
#     scaling_adjustment = -25
#     metric_interval_upper_bound = 0
#   }
# }

# resource "aws_cloudwatch_metric_alarm" "job_count_alarm_high" {
#   alarm_name          = "JobCountAlarmHighStep"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "BacklogPerInstance"
#   namespace           = var.cloudwatch_namespace
#   period              = "60"
#   statistic           = "Average"
#   threshold           = "1"

#   dimensions = {
#     Queue = aws_autoscaling_group.worker_nodes.name
#   }

#   alarm_description = "Monitors job backlog presence"
#   alarm_actions     = [aws_autoscaling_policy.worker_node_scale_out.arn]
# }

# resource "aws_cloudwatch_metric_alarm" "job_count_alarm_low" {
#   alarm_name          = "JobCountAlarmLowStep"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "7"
#   metric_name         = "BacklogPerInstance"
#   namespace           = var.cloudwatch_namespace
#   period              = "60"
#   statistic           = "Average"
#   threshold           = "1"

#   dimensions = {
#     Queue = aws_autoscaling_group.worker_nodes.name
#   }

#   alarm_description = "Monitors job backlog presence"
#   alarm_actions     = [aws_autoscaling_policy.worker_node_scale_in.arn]
# }

resource "aws_autoscaling_policy" "worker_node_autoscaling_policy" {
  name = "worker_node_autoscaling_policy"
  adjustment_type = "PercentChangeInCapacity"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.worker_nodes.name

  target_tracking_configuration {
    target_value = 0.99
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