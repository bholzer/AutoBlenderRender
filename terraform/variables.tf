variable "blender_node_image_id" {
  type = string
  default = "ami-02d6e6fad0a374703"
}

variable "frame_queue_bpi" {
  type = number
  default = 2
}

variable "project_init_queue_bpi" {
  type = number
  default = 5
}

variable "render_node_max_count" {
  type = number
  default = 20
}

variable "render_worker_asg_name" {
  type = string
  default = "render_workers"
}

variable "render_init_asg_name" {
  type = string
  default = "render_initializers"
}

variable "region" {
  type = string
  default = "us-east-1"
}

variable "availability_zone" {
  type = string
  default = "us-east-1a"
}

variable "vpc_cidr" {
  type = string
  default = "10.15.15.0/24"
}

variable "node_key_name" {
  type = string
}

variable "render_bucket_name" {
  type = string
  description = "Bucket name must be globally unique. Will be where blend files are uploaded and frames are rendered to"
}

variable "cloudwatch_namespace" {
  type = string
  description = "Namespace for rendering cloudwatch events"
  default = "ZipRender"
}
