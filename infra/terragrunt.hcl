locals {
  tags = try(yamldecode(file("${get_terragrunt_dir()}/tags.yml")), {})
  region = "us-east-1"
}

remote_state {
  backend = "s3"
  config = {
    bucket = "tfstate-${get_aws_account_id()}"
    key = "${path_relative_to_include()}/terraform.tfstate"
    region = local.region
    dynamodb_table = "tfstate-lock"
  }
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<-EOF
    provider "aws" {
      region = "${local.region}"
    }
  EOF
}

inputs = {
  tags = local.tags
}
