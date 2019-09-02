variable "cloudwatch_namespace" {
  type = string
  default = "BPI_emitter"
}

variable "asg_name" {
  type = string
}

variable "frame_queue" {
  type = string
}

variable "project_init_queue" {
  type = string
}

variable "frame_queue_bpi" {
  type = number
}

variable "project_init_queue_bpi" {
  type = number
}