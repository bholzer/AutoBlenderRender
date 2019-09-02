variable "key_name" {
  type = string
}

variable "image_id" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "instance_types" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}

variable "user_data" {
  type = string
}

variable "asg_name" {
  type = string
  default = "farm_node_group"
}

variable "asg_subnets" {
  type = list(string)
}

variable "asg_max_workers" {
  type = number
  default = 20
}

variable "asg_min_workers" {
  type = number
  default = 0
}

variable "cloudwatch_namespace" {
  type = string
  default = "QueueStats"
}