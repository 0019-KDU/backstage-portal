# ---------------------------------------------------------------------------
# outputs.tf — values printed after apply and used by service stacks later
# ---------------------------------------------------------------------------
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "alb_dns_name" {
  description = "Open http://<this> in a browser"
  value       = aws_lb.this.dns_name
}
output "http_listener_arn" { value = aws_lb_listener.http.arn }
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "tasks_security_group_id" { value = aws_security_group.tasks.id }
output "ecs_cluster_name" { value = aws_ecs_cluster.this.name }
output "ecs_cluster_arn" { value = aws_ecs_cluster.this.arn }
