# Base AMI must have a working blender installation, including dependencies
# Must also have ruby >= 2.5 with aws-sdk gems installed
variable "blender_node_image_id" {
  type = string
  default = "ami-0d4500bbcdea27e3c"
}

# Desired BacklogPerInstance for the frame render queue
variable "frame_queue_bpi" {
  type = number
  default = 2
}

# Desired BacklogPerInstance for project init queue
variable "project_init_queue_bpi" {
  type = number
  default = 5
}

# Maximum number of render nodes in farm
variable "worker_node_max_count" {
  type = number
  default = 20
}

variable "instance_types" {
  type = list(string)
  default = ["c5.9xlarge", "c4.8xlarge", "c5n.9xlarge", "c5.4xlarge"]
}

# Render worker ASG name
variable "worker_asg_name" {
  type = string
  default = "render_workers"
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
  default = ""
  description = "Bucket name must be globally unique. Will be where blend files are uploaded and frames are rendered to"
}

variable "cloudwatch_namespace" {
  type = string
  description = "Namespace for rendering cloudwatch events"
  default = "RenderFarm"
}
