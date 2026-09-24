output "environment" { value = var.environment }
output "vpc_id" { value = aws_vpc.this.id }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "base_url" { value = "http://${aws_lb.this.dns_name}" }
output "ecs_cluster_name" { value = aws_ecs_cluster.this.name }
output "deploy_role_arn" { value = aws_iam_role.deploy.arn }
output "ecs_infrastructure_role_arn" { value = aws_iam_role.ecs_infrastructure.arn }
