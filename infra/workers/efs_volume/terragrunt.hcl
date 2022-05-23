include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}

dependency "vpc" {
  config_path = "../../vpc"
}

terraform {
  source = "git@github.com:bholzer/aws-modules.git//efs/volume"
}

inputs = {
  name = local.config.name
  vpc_id = dependency.vpc.outputs.vpc.id
  subnet_ids = [ for k, sub in dependency.vpc.outputs.private_subnets: sub.id ]
}
