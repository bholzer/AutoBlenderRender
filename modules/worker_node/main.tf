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

  user_data = var.user_data
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