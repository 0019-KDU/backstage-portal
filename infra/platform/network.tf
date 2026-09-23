# ---------------------------------------------------------------------------
# network.tf — VPC with two PUBLIC subnets and no NAT Gateway
#
# Cost decision for the demo: a NAT Gateway costs ~$35+/month. Instead, Fargate
# tasks get a public IP (to pull images from ECR) but their security group only
# accepts traffic from the load balancer, so they are not reachable directly.
# Production would use private subnets + NAT or VPC endpoints.
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

# Door between the VPC and the internet
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# One /20 subnet per AZ: 10.20.0.0/20 and 10.20.16.0/20 (4,096 IPs each)
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = false # tasks get a public IP explicitly per service
  tags                    = { Name = "${var.name}-public-${var.availability_zones[count.index]}", tier = "public" }
}

# Route table: "everything not local goes to the internet gateway"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
