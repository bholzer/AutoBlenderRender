resource "aws_iam_role" "render_node_role" {
  name = "render_node_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "render_node_sqs_policy" {
  name = "render_node_sqs_policy"
  path = "/"
  description = "SQS access for grabbing frames/blendfiles"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sqs:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "render_node_s3_policy" {
  name = "render_node_s3_policy"
  path = "/"
  description = "S3 access for grabbing blendfiles and storing render output"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "render_node_autoscale_policy" {
  name = "render_node_autoscale_policy"
  path = "/"
  description = "Autoscale access for protecting from scale-in during render"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "autoscaling:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "autoscaling.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sqs_attach_policy" {
  role = aws_iam_role.render_node_role.name
  policy_arn = aws_iam_policy.render_node_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "s3_attach_policy" {
  role = aws_iam_role.render_node_role.name
  policy_arn = aws_iam_policy.render_node_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "autoscale_attach_policy" {
  role = aws_iam_role.render_node_role.name
  policy_arn = aws_iam_policy.render_node_autoscale_policy.arn
}

resource "aws_iam_instance_profile" "render_node_profile" {
  name = "render_node_profile"
  role = aws_iam_role.render_node_role.name
}
