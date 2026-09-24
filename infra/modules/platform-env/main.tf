data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  prefix     = "devops94-idp-${var.environment}" # every name in this env starts with this
  svc_prefix = "${local.prefix}-svc"             # per-service resources created by pipelines
  # Target group names are limited to 32 chars: d94d-/d94s-/d94p- + service name + -b/-g
  tg_prefix  = "d94${substr(var.environment, 0, 1)}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# ============================ network ======================================
# Public subnets (ALB + Fargate tasks with outbound public IP; no NAT in the demo)
# Private subnets (databases; no route to the internet at all)
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.prefix}-igw" }
}

resource "aws_subnet" "public" {
  count             = length(var.public_azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.public_azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  tags              = { Name = "${local.prefix}-public-${var.public_azs[count.index]}", tier = "public" }
}

resource "aws_subnet" "private" {
  count             = length(var.private_azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.private_azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  tags              = { Name = "${local.prefix}-private-${var.private_azs[count.index]}", tier = "private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.prefix}-public" }
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.prefix}-private" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================ security groups ==============================
#   Internet --80--> [alb] --8080--> [ecs-tasks] --5432--> [db]
resource "aws_security_group" "alb" {
  name        = "${local.prefix}-alb"
  description = "Public load balancer (${var.environment})"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.prefix}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere (demo has no domain, so no TLS certificate on the ALB)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB may only talk to service containers"
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_security_group" "tasks" {
  name        = "${local.prefix}-ecs-tasks"
  description = "Fargate service tasks (${var.environment})"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.prefix}-ecs-tasks" }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Only the ALB can reach containers"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "tasks_out" {
  security_group_id = aws_security_group.tasks.id
  description       = "Outbound: ECR, logs, APIs, databases"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "${local.prefix}-db"
  description = "PostgreSQL databases (${var.environment}): only ECS tasks of this environment"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.prefix}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_tasks" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from ECS tasks of this environment"
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# ============================ load balancer ================================
resource "aws_lb" "this" {
  name                       = "${local.prefix}-alb"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
  tags                       = { Name = "${local.prefix}-alb" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "DevOps94 IDP (${var.environment}): no service is mapped to this path"
      status_code  = "404"
    }
  }
}

# ============================ ECS cluster ==================================
resource "aws_ecs_cluster" "this" {
  name = "${local.prefix}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# Role ECS itself uses to switch ALB traffic during blue/green deployments
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_infrastructure" {
  name               = "${local.prefix}-ecs-infra"
  description        = "ECS blue/green: lets ECS move traffic between target groups (${var.environment})"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  role       = aws_iam_role.ecs_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}
