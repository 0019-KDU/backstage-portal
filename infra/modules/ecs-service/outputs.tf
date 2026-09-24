output "url" {
  description = "Public URL of this service in this environment"
  value       = "http://${data.aws_lb.env.dns_name}${local.path}/"
}
output "ecs_service_name" { value = aws_ecs_service.this.name }
output "ecs_service_arn" { value = aws_ecs_service.this.id }
output "ecs_cluster_name" { value = data.aws_ecs_cluster.env.cluster_name }
output "log_group_name" { value = aws_cloudwatch_log_group.this.name }
output "task_definition_arn" { value = aws_ecs_task_definition.this.arn }
output "deployment_strategy" { value = var.deployment_strategy }
