# ---------------------------------------------------------------------------
# security.tf — two firewalls (security groups)
#
#   Internet --80--> [alb SG] --8080--> [tasks SG]
#
# Rules are separate resources (aws_vpc_security_group_*_rule), the pattern the
# AWS provider recommends over inline rules: each rule is tracked individually.
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public load balancer"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-alb" }
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
  name        = "${var.name}-ecs-tasks"
  description = "Fargate service tasks"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name}-ecs-tasks" }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Only the ALB can reach containers (not the internet)"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "tasks_out" {
  security_group_id = aws_security_group.tasks.id
  description       = "Outbound: pull images from ECR, send logs, call APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
