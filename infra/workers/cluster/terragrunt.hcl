include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}

terraform {
  source = "git@github.com:bholzer/aws-modules.git//ecs/cluster"
}

inputs = {
  name = local.config.name
}