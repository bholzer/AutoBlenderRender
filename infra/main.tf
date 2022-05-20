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
}

data "aws_caller_identity" "current" {}

resource "random_string" "id" {
  length = 16
  special = false
  upper = false
  number = false
}

module "vpc" {
  source = "github.com/bholzer/aws-modules//vpc/vpc"
  
}
