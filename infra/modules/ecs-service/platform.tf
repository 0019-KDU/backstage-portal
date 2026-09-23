# ---------------------------------------------------------------------------
# platform.tf — FIND the shared platform (read-only data sources, by name/tag)
# Services never need the platform's state file or its IDs hard-coded.
# ---------------------------------------------------------------------------
data "aws_region" "current" {}

data "aws_vpc" "platform" {
  tags = { Name = "${var.platform_name}-vpc" }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = { tier = "public" }
}

data "aws_security_group" "tasks" {
  vpc_id = data.aws_vpc.platform.id
  name   = "${var.platform_name}-ecs-tasks"
}

data "aws_lb" "platform" {
  name = "${var.platform_name}-alb"
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.platform.arn
  port              = 80
}

data "aws_ecs_cluster" "platform" {
  cluster_name = "${var.platform_name}-cluster"
}

locals {
  # devops94-idp-svc-reference-api-dev  (prefix required by the IAM policies)
  full_name = "${var.platform_name}-svc-${var.name}-${var.environment}"
  base_path = "/${var.environment}/${var.name}"
  use_spot  = coalesce(var.use_spot, var.environment != "prod")

  tags = merge(var.tags, {
    # These two tags let the Backstage ECS plugin find the service
    # (annotation aws.amazon.com/amazon-ecs-service-tags: component=<name>,environment=<env>)
    component   = var.name
    environment = var.environment
  })
}
