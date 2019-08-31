# Build up the vpc and subnets
resource "aws_vpc" "render_farm_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
}

resource "aws_subnet" "main_subnet" {
  vpc_id = aws_vpc.render_farm_vpc.id
  cidr_block = var.vpc_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "Main"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.render_farm_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.render_farm_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}
