data "archive_file" "s3_upload_handler" {
  type = "zip"
  source_dir = "${path.module}/lambda"
  output_path = "${path.module}/lambda/s3_upload_handler.zip"
}

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
  filename = "${path.module}/lambda/s3_upload_handler.zip"
  function_name = "s3_upload_handler"
  role = aws_iam_role.s3_upload_handler_role.arn
  handler = "s3_upload_handler.lambda_handler"
  runtime = "ruby2.5"

  environment {
    variables = {
      BUCKET = var.bucket_name
      PROJECT_INIT_QUEUE = var.project_init_queue
    }
  }
}

resource "aws_s3_bucket_notification" "blend_upload_notification" {
  bucket = var.bucket_name

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
  source_arn    = var.bucket_arn
}
