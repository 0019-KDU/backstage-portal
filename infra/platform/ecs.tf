# ---------------------------------------------------------------------------
# ecs.tf — the ECS cluster (a logical group; with Fargate there are no servers)
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  # CPU/memory/task metrics per service in CloudWatch (small extra cost)
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Which "engines" services may run on:
#   FARGATE      = on-demand
#   FARGATE_SPOT = up to ~70% cheaper, can be interrupted (good for dev)
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}
