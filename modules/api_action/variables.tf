variable "controller" {
  type = string
}

variable "method" {
  type = string
}

variable "action" {
  type = string
}

variable "rest_api" {
  type = any
}

variable "api_resource" {
  type = any
}

variable "deployment" {
  type = any
}


variable "region" {
  type = string
}

variable "dynamo_tables" {
  type = map
}

variable "bucket" {
  type = string
}