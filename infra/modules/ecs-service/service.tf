# ---------------------------------------------------------------------------
# service.tf — task definition (the recipe) + service (keeps it running)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.full_name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.full_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name                   = "app"
    image                  = var.image
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]

    environment = [for k, v in merge({
      PORT         = tostring(var.container_port)
      BASE_PATH    = local.path
      SERVICE_NAME = var.name
      ENVIRONMENT  = var.environment
    }, var.environment_variables) : { name = k, value = v }]

    # Injected by ECS at start from Secrets Manager; never in code, image or Terraform state
    secrets = [for k, v in var.secrets : { name = k, valueFrom = v }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "app"
      }
    }
  }])

  tags = local.tags
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = data.aws_ecs_cluster.env.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.min_tasks

  capacity_provider_strategy {
    capacity_provider = local.use_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.public.ids # 2 AZs
    security_groups  = [data.aws_security_group.tasks.id]
    assign_public_ip = true # no NAT in the demo VPC; inbound still only from the ALB
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "app"
    container_port   = var.container_port

    dynamic "advanced_configuration" {
      for_each = local.blue_green ? [1] : []
      content {
        alternate_target_group_arn = aws_lb_target_group.green[0].arn
        production_listener_rule   = local.listener_rule_arn
        role_arn                   = data.aws_iam_role.ecs_infrastructure[0].arn
      }
    }
  }

  # ROLLING: replace tasks gradually. BLUE_GREEN: start the full new version,
  # switch traffic, keep the old one for bake_time minutes (instant rollback).
  deployment_configuration {
    strategy             = var.deployment_strategy
    bake_time_in_minutes = local.blue_green ? var.bake_time_minutes : null
  }
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  # New tasks keep failing -> stop and roll back automatically
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  wait_for_steady_state   = true # CI waits for the real outcome
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  tags                    = local.tags

  lifecycle {
    ignore_changes = [desired_count] # owned by autoscaling
  }

  depends_on = [aws_lb_listener_rule.rolling, aws_lb_listener_rule.blue_green]
}
