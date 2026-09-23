# ---------------------------------------------------------------------------
# alb.tf — one shared Application Load Balancer for all demo services
#
# Each service later adds its own "listener rule" (path-based routing, e.g.
# /dev/orders/* -> orders-dev target group). Without a domain we route by
# path instead of hostname. Unknown paths get a friendly 404.
# ---------------------------------------------------------------------------
resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true # security hardening (HTTP desync protection)
  tags                       = { Name = "${var.name}-alb" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "DevOps94 IDP: no service is mapped to this path"
      status_code  = "404"
    }
  }
}
