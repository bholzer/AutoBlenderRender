include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}

terraform {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"
}

dependency "vpc" {
  config_path = "../../../vpc"
}

dependency "projects_table" {
  config_path = "../../../tables/projects"
}

dependency "bucket" {
  config_path = "../../../bucket"
}

inputs = {
  name = "${local.config.name}-blends-create"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = [ for k, sub in dependency.vpc.outputs.private_subnets: sub.id ]
    security_group_ids = []
  }
  timeout = 10
  environment = {
    PROJECTS_TABLE = dependency.projects_table.outputs.table.name
    BUCKET_NAME = dependency.bucket.outputs.bucket.id
  }
  policy_arns = [
    dependency.projects_table.outputs.read_policy.arn,
    dependency.projects_table.outputs.write_policy.arn,
    dependency.bucket.outputs.read_policy.arn,
    dependency.bucket.outputs.write_policy.arn
  ]
}
