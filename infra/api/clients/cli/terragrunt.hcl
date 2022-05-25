include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}


terraform {
  source = "git@github.com:bholzer/aws-modules.git//cognito/client"
}

dependency "user_pool" {
  config_path = "../../../user_pool"
}

inputs = {
  name = "CLI"
  user_pool_id = dependency.user_pool.outputs.user_pool.id
  explicit_auth_flows = [
    "USER_PASSWORD_AUTH"
  ]
}
