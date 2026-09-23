# ---------------------------------------------------------------------------
# rds-postgres — a private, encrypted PostgreSQL database for one team/service.
# Guardrails (not configurable by the requester):
#   private subnets only · not publicly accessible · storage encrypted
#   · reachable only from ECS service tasks (security group) · password never in
#   Terraform/Git: RDS generates it and stores it in Secrets Manager
#   · automated backups (point-in-time recovery) · minor version auto-upgrades
# ---------------------------------------------------------------------------
variable "name" {
  description = "Database name (becomes devops94-idp-res-<name>)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "name: 3-22 chars, lowercase letters, digits and '-', starts with a letter."
  }
}
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
  validation {
    condition     = contains(["db.t4g.micro", "db.t4g.small", "db.t4g.medium"], var.instance_class)
    error_message = "instance_class must be db.t4g.micro, db.t4g.small or db.t4g.medium."
  }
}
variable "allocated_storage_gb" {
  type    = number
  default = 20
  validation {
    condition     = var.allocated_storage_gb >= 20 && var.allocated_storage_gb <= 100
    error_message = "allocated_storage_gb must be between 20 and 100."
  }
}
variable "engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "17"
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "deletion_protection" {
  description = "Set true for anything that must not be deleted by accident"
  type        = bool
  default     = false
}
variable "platform_name" {
  type    = string
  default = "devops94-idp"
}
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  full_name = "${var.platform_name}-res-${var.name}"
  db_name   = replace(var.name, "-", "_")
  tags      = merge(var.tags, { resource = var.name, resource-type = "rds-postgres" })
}

data "aws_vpc" "platform" {
  tags = { Name = "${var.platform_name}-vpc" }
}
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = { tier = "private" }
}
data "aws_security_group" "ecs_tasks" {
  vpc_id = data.aws_vpc.platform.id
  name   = "${var.platform_name}-ecs-tasks"
}

resource "aws_db_subnet_group" "this" {
  name       = local.full_name
  subnet_ids = data.aws_subnets.private.ids
  tags       = local.tags
}

resource "aws_security_group" "db" {
  name        = "${local.full_name}-db"
  description = "PostgreSQL ${var.name}: only ECS service tasks may connect"
  vpc_id      = data.aws_vpc.platform.id
  tags        = merge(local.tags, { Name = "${local.full_name}-db" })
}

resource "aws_vpc_security_group_ingress_rule" "from_ecs" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from ECS service tasks"
  referenced_security_group_id = data.aws_security_group.ecs_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "this" {
  identifier                  = local.full_name
  engine                      = "postgres"
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage_gb
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = local.db_name
  username                    = "app_admin"
  manage_master_user_password = true # generated + stored in Secrets Manager
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  multi_az                    = false # demo cost; production: true
  backup_retention_period     = var.backup_retention_days
  copy_tags_to_snapshot       = true
  auto_minor_version_upgrade  = true
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = true # demo; production: false + final_snapshot_identifier
  apply_immediately           = true
  tags                        = local.tags
}

output "identifier" { value = aws_db_instance.this.identifier }
output "endpoint" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "database_name" { value = aws_db_instance.this.db_name }
output "username" { value = aws_db_instance.this.username }
output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the generated password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
output "console_url" {
  value = "https://${data.aws_vpc.platform.region}.console.aws.amazon.com/rds/home?region=${data.aws_vpc.platform.region}#database:id=${aws_db_instance.this.identifier}"
}
