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

inputs = {
  name = "${local.config.name}-blends-create"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = [ for k, sub in dependency.vpc.outputs.private_subnets: sub.id ]
    security_group_ids = []
  }
}
