variable "region" {
  type = string
}

variable "bucket" {
  type = string
}

variable "dynamo_tables" {
  type = map
}

variable "frame_queue" {
  type = string
}

variable "project_init_queue" {
  type = string
}