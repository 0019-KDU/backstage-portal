# ---------------------------------------------------------------------------
# routing.tf — how requests reach this service through the shared ALB
#   http://<alb>/<environment>/<name>/...  ->  target group  ->  task IPs :8080
# ---------------------------------------------------------------------------
resource "aws_lb_target_group" "this" {
  name                 = "d94-${var.name}-${var.environment}" # <= 32 chars
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip" # required for Fargate (awsvpc networking)
  vpc_id               = data.aws_vpc.platform.id
  deregistration_delay = 15 # faster deploys; default 300s

  health_check {
    path                = "${local.base_path}/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = data.aws_lb_listener.http.arn
  # priority omitted: AWS picks the next free one, so services never collide

  condition {
    path_pattern {
      values = [local.base_path, "${local.base_path}/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = local.tags
}
