# ---------------------------------------------------------------------------
# rds-postgres — a private, encrypted PostgreSQL database for one team/service.
# Guardrails (not configurable by the requester):
#   private subnets only · not publicly accessible · storage encrypted
#   · reachable only from ECS tasks of the SAME environment (env db security group)
#   · password never in
#   Terraform/Git: RDS generates it and stores it in Secrets Manager
#   · automated backups (point-in-time recovery) · minor version auto-upgrades
# ---------------------------------------------------------------------------
variable "name" {
  description = "Database name (becomes devops94-idp-<env>-<kind>-<name>)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "name: 3-22 chars, lowercase letters, digits and '-', starts with a letter."
  }
}
variable "environment" {
  description = "dev | staging | prod: which environment's network this lives in"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}
variable "kind" {
  description = "res = requested via self-service; svc = owned by a golden-path service"
  type        = string
  default     = "res"
  validation {
    condition     = contains(["res", "svc"], var.kind)
    error_message = "kind must be res or svc."
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
  env_prefix = "${var.platform_name}-${var.environment}"
  full_name  = "${local.env_prefix}-${var.kind}-${var.name}"
  db_name    = replace(var.name, "-", "_")
  tags       = merge(var.tags, { resource = var.name, resource-type = "rds-postgres", environment = var.environment })
}

data "aws_vpc" "platform" {
  tags = { Name = "${local.env_prefix}-vpc" }
}
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = { tier = "private" }
}
# Shared per-environment database security group (platform-env): PostgreSQL only
# from that environment's ECS tasks.
data "aws_security_group" "db" {
  vpc_id = data.aws_vpc.platform.id
  name   = "${local.env_prefix}-db"
}

resource "aws_db_subnet_group" "this" {
  name       = local.full_name
  subnet_ids = data.aws_subnets.private.ids
  tags       = local.tags
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
  vpc_security_group_ids      = [data.aws_security_group.db.id]
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
