resource "aws_api_gateway_method" "action_method" {
  rest_api_id   = var.rest_api.id
  resource_id   = var.api_resource.id
  http_method   = var.method
  authorization = var.authorization
  authorizer_id = var.authorizer_id
}

resource "aws_api_gateway_integration" "lambda_action_integration" {
  rest_api_id             = var.rest_api.id
  resource_id             = var.api_resource.id
  http_method             = aws_api_gateway_method.action_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda_action.arn}/invocations"
}

resource "aws_lambda_permission" "lambda_action_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_action.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${var.deployment.execution_arn}/${aws_api_gateway_method.action_method.http_method}${var.api_resource.path}"
}

resource "aws_iam_role" "lambda_action_role" {
  name = "lambda_action_role-${var.controller}${var.method}${var.action}"

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

resource "aws_iam_policy" "dynamo_table_policy" {
  name        = "dynamoTablePolicy${var.controller}${var.method}${var.action}"
  path        = "/"
  description = "Dyanmo Access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "cloudwatch_log_policy" {
  name        = "cloudwatchLogPolicy${var.controller}${var.method}${var.action}"
  path        = "/"
  description = "Policy for creating cloudwatch logs"

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
        "logs:DescribeLogStreams"
    ],
      "Resource": [
        "arn:aws:logs:*:*:*"
    ]
  }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dynamo_attach_policy" {
  role = aws_iam_role.lambda_action_role.name
  policy_arn = aws_iam_policy.dynamo_table_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_log_attach_policy" {
  role = aws_iam_role.lambda_action_role.name
  policy_arn = aws_iam_policy.cloudwatch_log_policy.arn
}

resource "aws_iam_role_policy_attachment" "s3_attach_policy" {
  role = aws_iam_role.lambda_action_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs_attach_policy" {
  role = aws_iam_role.lambda_action_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "${path.root}/src/api/${var.controller}/${var.action}.rb"
  output_path = "${path.root}/src/api/archives/${var.controller}/${var.action}.zip"
}

resource "aws_lambda_function" "lambda_action" {
  filename = "${path.root}/src/api/archives/${var.controller}/${var.action}.zip"
  function_name = "${var.controller}_${var.action}"
  role = aws_iam_role.lambda_action_role.arn
  handler = "${var.action}.lambda_handler"
  runtime = "ruby2.5"
  timeout = 5
  layers = [var.api_lambda_layer]

  environment {
    variables = merge({
      REGION = var.region,
      BUCKET = var.bucket,
      FRAME_QUEUE = var.frame_queue,
      PROJECT_INIT_QUEUE = var.project_init_queue
    }, {
      for table in keys(var.dynamo_tables):
        "${upper(table)}_TABLE" => lookup(var.dynamo_tables, table)
    })
  }
}
