# ---------------------------------------------------------------------------
# platform.tf — FIND this environment's platform (by name; no IDs hard-coded)
# ---------------------------------------------------------------------------
data "aws_region" "current" {}

locals {
  env_prefix = "${var.platform_name}-${var.environment}" # devops94-idp-dev
  full_name  = "${local.env_prefix}-svc-${var.name}"     # devops94-idp-dev-svc-orders
  tg_prefix  = "d94${substr(var.environment, 0, 1)}-${var.name}"
  path       = "/${var.name}" # one ALB per environment
  blue_green = var.deployment_strategy == "BLUE_GREEN"
  use_spot   = coalesce(var.use_spot, var.environment == "dev")

  tags = merge(var.tags, {
    # Backstage uses these: ECS plugin (service lookup) and Cost Insights (component=<name>)
    component   = var.name
    environment = var.environment
  })
}

data "aws_vpc" "env" {
  tags = { Name = "${local.env_prefix}-vpc" }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.env.id]
  }
  tags = { tier = "public" }
}

data "aws_security_group" "tasks" {
  vpc_id = data.aws_vpc.env.id
  name   = "${local.env_prefix}-ecs-tasks"
}

data "aws_lb" "env" {
  name = "${local.env_prefix}-alb"
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.env.arn
  port              = 80
}

data "aws_ecs_cluster" "env" {
  cluster_name = "${local.env_prefix}-cluster"
}

# Role ECS uses to switch traffic during blue/green (created by platform-env)
data "aws_iam_role" "ecs_infrastructure" {
  count = local.blue_green ? 1 : 0
  name  = "${local.env_prefix}-ecs-infra"
}
