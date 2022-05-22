variable "name" {
  type = string
  description = "Name of the render farm"
  default = "AutoBlenderRender"
}

variable "vpc_cidr" {
  type = string
  description = "VPC CIDR block"
  default = "10.52.145.0/24"
}

variable "private_subnet_cidrs" {
  type = list(string)
  description = "CIDR blocks of private subnets in VPC"
  default = ["10.52.145.0/25", "10.52.145.128/25"]
}

variable "az_count" {
  type = number
  description = "Number of availability zones in which to distibute subnets"
  default = 2
}

variable "client_endpoint" {
  type = string
  default = "https://example.com"
}
