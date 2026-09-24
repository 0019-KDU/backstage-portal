# ---------------------------------------------------------------------------
# routing.tf — http://<env-alb>/<name>/...  ->  target group  ->  tasks :8080
# BLUE_GREEN uses two target groups; ECS moves the weights between them.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "blue" {
  name                 = "${local.tg_prefix}-b"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.env.id
  deregistration_delay = 15

  health_check {
    path                = "${local.path}/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = local.tags
}

resource "aws_lb_target_group" "green" {
  count                = local.blue_green ? 1 : 0
  name                 = "${local.tg_prefix}-g"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.env.id
  deregistration_delay = 15

  health_check {
    path                = "${local.path}/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = local.tags
}

# ROLLING: simple forward to the one target group
resource "aws_lb_listener_rule" "rolling" {
  count        = local.blue_green ? 0 : 1
  listener_arn = data.aws_lb_listener.http.arn
  condition {
    path_pattern {
      values = [local.path, "${local.path}/*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
  tags = local.tags
}

# BLUE_GREEN: weighted forward (100% blue at creation). During each deployment ECS
# rewrites these weights, so Terraform must not "fix" them back.
resource "aws_lb_listener_rule" "blue_green" {
  count        = local.blue_green ? 1 : 0
  listener_arn = data.aws_lb_listener.http.arn
  condition {
    path_pattern {
      values = [local.path, "${local.path}/*"]
    }
  }
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.green[0].arn
        weight = 0
      }
    }
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [action] # owned by ECS after the first deployment
  }
}

locals {
  listener_rule_arn = local.blue_green ? aws_lb_listener_rule.blue_green[0].arn : aws_lb_listener_rule.rolling[0].arn
}
