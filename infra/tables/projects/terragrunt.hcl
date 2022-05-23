include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}

terraform {
  source = "git@github.com:bholzer/aws-modules.git//dynamo/table"
}

inputs = {
  name = "${local.config.name}-projects"
  hash_key = "hk"
  range_key = "rk"
  billing_mode = "PAY_PER_REQUEST"
  attributes = [
    {name = "hk", type = "S"},
    {name = "rk", type = "S"}
  ]
}
