include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}

terraform {
  source = "git@github.com:bholzer/aws-modules.git//vpc/vpc"
}

inputs = {
  name = local.config.name
  cidr_block = local.config.vpc_cidr
  private_subnet_cidrs = local.config.private_subnet_cidrs
  az_count = local.config.az_count
}
