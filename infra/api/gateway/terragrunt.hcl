include {
  path = find_in_parent_folders()
}

locals {
  config = merge(
    yamldecode(file(find_in_parent_folders("global_config.yml")))
  )
}


terraform {
  source = "git@github.com:bholzer/aws-modules.git//api_gateway/gateway"
}

dependency "user_pool" {
  config_path = "../../user_pool"
}

dependency "projects_index" {
  config_path = "../projects/index"
}

dependency "projects_create" {
  config_path = "../projects/create"
}

dependency "projects_show" {
  config_path = "../projects/show"
}

dependency "projects_destroy" {
  config_path = "../projects/destroy"
}

dependency "blends_index" {
  config_path = "../blends/index"
}

dependency "blends_create" {
  config_path = "../blends/create"
}

dependency "blends_show" {
  config_path = "../blends/show"
}

dependency "blends_destroy" {
  config_path = "../blends/destroy"
}

inputs = {
  name = local.config.name
  description = "API for AutoBlenderRender render farm"
  routes = {
    "GET /projects" = {
      type = "lambda"
      function_name = dependency.projects_index.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "GET /projects/{projectId}" = {
      type = "lambda"
      function_name = dependency.projects_show.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "POST /projects" = {
      type = "lambda"
      function_name = dependency.projects_create.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "DELETE /projects/{projectId}" = {
      type = "lambda"
      function_name = dependency.projects_destroy.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "GET /projects/{projectId}/blends" = {
      type = "lambda"
      function_name = dependency.blends_index.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "GET /projects/{projectId}/blends/{blendId}" = {
      type = "lambda"
      function_name = dependency.blends_show.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "POST /projects/{projectId}/blends" = {
      type = "lambda"
      function_name = dependency.blends_create.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    },
    "DELETE /projects/{projectId}/blends/{blendId}" = {
      type = "lambda"
      function_name = dependency.blends_destroy.outputs.function.function_name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${dependency.user_pool.outputs.user_pool.endpoint}"
      }
    }
  }
}
