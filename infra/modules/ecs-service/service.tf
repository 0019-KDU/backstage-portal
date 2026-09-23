# ---------------------------------------------------------------------------
# service.tf — what runs: task definition (the "recipe") + service (keeps N copies running)
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
    readonlyRootFilesystem = true # the app cannot modify its own filesystem
    portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]

    environment = [for k, v in merge({
      PORT         = tostring(var.container_port)
      BASE_PATH    = local.base_path
      SERVICE_NAME = var.name
      ENVIRONMENT  = var.environment
    }, var.environment_variables) : { name = k, value = v }]

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
  name            = "${var.name}-${var.environment}"
  cluster         = data.aws_ecs_cluster.platform.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = local.use_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [data.aws_security_group.tasks.id]
    assign_public_ip = true # no NAT in the demo VPC; SG still blocks inbound except from ALB
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # Rolling deploy: start new tasks first (200%), never drop below 100% healthy
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 30

  # If new tasks keep failing, ECS stops the deploy and rolls back automatically
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # `terraform apply` waits until the deploy is healthy (or fails), so CI shows the truth
  wait_for_steady_state = true

  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  tags                    = local.tags

  depends_on = [aws_lb_listener_rule.this] # target group must be attached to the ALB first
}
