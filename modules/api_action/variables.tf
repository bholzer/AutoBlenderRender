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

variable "frame_queue" {
  type = string
}

variable "project_init_queue" {
  type = string
}

variable "authorization" {
  type = string
}

variable "authorizer_id" {
  type = string
}

variable "api_lambda_layer" {
  type = string
}