data "archive_file" "bpi_lambda_zip" {
  type = "zip"
  source_dir = "${path.module}/lambda"
  output_path = "${path.module}/lambda/bpi_metric_emitter.zip"
}

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
  filename = "${path.module}/lambda/bpi_metric_emitter.zip"
  function_name = "bpi_metric_emitter"
  role = aws_iam_role.bpi_metric_emitter_role.arn
  handler = "bpi_metric_emitter.lambda_handler"
  runtime = "ruby2.5"

  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = var.cloudwatch_namespace
      ASG_NAME = var.asg_name
      FRAME_QUEUE = var.frame_queue
      FRAME_QUEUE_BPI = var.frame_queue_bpi
      PROJECT_INIT_QUEUE = var.project_init_queue
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
