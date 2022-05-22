/**
 *  Creates the infrastructure for the AutoBlenderRender render farm.
 *
 */

terraform {
  required_version = ">= 1.1.9"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.12.1"
    }
  }

  backend "s3" {}
}

data "aws_caller_identity" "current" {}


resource "random_string" "id" {
  length = 16
  special = false
  upper = false
  number = false
}

module "vpc" {
  source = "git@github.com:bholzer/aws-modules.git//vpc/vpc"

  cidr_block = var.vpc_cidr
  private_subnets = var.private_subnet_cidrs
  zone_count = var.az_count
  create_internet_gateway = false
  create_nat = false
}

module "worker_cluster" {
  source = "git@github.com:bholzer/aws-modules.git//s3/bucket"

  name = "${var.name}-worker-cluster"
}

module "bucket" {
  source = "git@github.com:bholzer/aws-modules.git//s3/bucket"

  name = var.name
}

module "efs" {
  source = "git@github.com:bholzer/aws-modules.git//efs/volume"

  name = var.name
  vpc_id = module.vpc.vpc.id
  subnet_ids = module.vpc.private_subnets[*].id
}

module "render_queue" {
  source = "git@github.com:bholzer/aws-modules.git//sqs/queue"

  name = "${var.name}-render"
}

module "projects_table" {
  source = "git@github.com:bholzer/aws-modules.git//dynamo/table"

  name = "${var.name}-projects"
  hash_key = "hk"
  range_key = "rk"
  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {name = "hk", type = "S"},
    {name = "rk", type = "S"}
  ]
}

# API endpoint functions

module "projects_index" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-projects-index"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "projects_show" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-projects-show"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "projects_create" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-projects-create"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "projects_destroy" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-projects-destroy"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "blends_index" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-blends-index"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "blends_show" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-blends-show"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "blends_create" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-blends-create"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "blends_destroy" {
  source = "git@github.com:bholzer/aws-modules.git//lambda/function"

  name = "${var.name}-blends-destroy"
  runtime = "ruby2.7"
  vpc_config = {
    subnet_ids = module.vpc.private_subnets[*].id
    security_group_ids = []
  }
}

module "user_pool" {
  source = "git@github.com:bholzer/aws-modules.git//cognito/user_pool"

  name = var.name
  callback_urls = [var.client_endpoint]
  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
}

module "api" {
  source = "git@github.com:bholzer/aws-modules.git//api_gateway/gateway"

  name = var.name
  description = "API for AutoBlenderRender render farm"
  routes = {
    "GET /projects" = {
      function_name = module.projects_index.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "GET /projects/{projectId}" = {
      function_name = module.projects_show.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "POST /projects" = {
      function_name = module.projects_create.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "DELETE /projects/{projectId}" = {
      function_name = module.projects_destroy.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "GET /projects/{projectId}/blends" = {
      function_name = module.blends_index.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "GET /projects/{projectId}/blends/{blendId}" = {
      function_name = module.blends_show.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "POST /projects/{projectId}/blends" = {
      function_name = module.blends_create.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    },
    "DELETE /projects/{projectId}/blends/{blendId}" = {
      function_name = module.blends_destroy.function.name,
      auth = {
        source = "$request.header.Authorization"
        audience = "farm"
        issuer = "https://${module.user_pool.pool.endpoint}"
      }
    }
  }
}
