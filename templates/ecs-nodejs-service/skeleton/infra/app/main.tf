# ---------------------------------------------------------------------------
# ${{ values.name }} in ONE environment (var.environment): database + service.
# The same code is applied to dev, staging and prod with env/<env>.tfvars.
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name  = "${{ values.name }}"
  image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/devops94-idp-svc-${local.name}:${var.image_tag}"
  tags  = { owner = "${{ values.owner }}", system = "idp-demo" }
}

# Private PostgreSQL for this service in this environment. RDS generates the
# password and keeps it in Secrets Manager; ECS injects it at container start.
module "db" {
  count                 = var.use_database ? 1 : 0
  source                = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/rds-postgres?ref=main"
  name                  = local.name
  environment           = var.environment
  kind                  = "svc"
  instance_class        = var.db_instance_class
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  tags                  = local.tags
}

# Resources this service uses (requested in Backstage, e.g. an S3 bucket or extra database):
# one JSON file per resource in bindings/<environment>/, added by the Backstage request.
locals {
  binding_dir = "${path.module}/bindings/${var.environment}"
  bindings    = [for f in fileset(local.binding_dir, "*.json") : jsondecode(file("${local.binding_dir}/${f}"))]
}

module "bindings" {
  source      = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/service-bindings?ref=main"
  environment = var.environment
  bindings    = local.bindings
}

module "service" {
  source      = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/ecs-service?ref=main"
  name        = local.name
  environment = var.environment
  image       = local.image

  deployment_strategy = var.deployment_strategy
  bake_time_minutes   = var.bake_time_minutes
  cpu                 = var.cpu
  memory              = var.memory
  min_tasks           = var.min_tasks
  max_tasks           = var.max_tasks

  environment_variables = merge(
    { APP_VERSION = var.image_tag },
    module.bindings.environment_variables,
    var.use_database ? {
      DB_HOST = module.db[0].endpoint
      DB_PORT = tostring(module.db[0].port)
      DB_NAME = module.db[0].database_name
      DB_USER = module.db[0].username
      DB_SSL  = "true"
    } : {}
  )
  secrets = merge(
    var.use_database ? { DB_PASSWORD = "${module.db[0].master_user_secret_arn}:password::" } : {},
    module.bindings.secrets
  )
  secret_arns      = concat(var.use_database ? [module.db[0].master_user_secret_arn] : [], module.bindings.secret_arns)
  task_policy_json = module.bindings.task_policy_json
  tags             = local.tags
}

output "url" { value = module.service.url }
output "deployment_strategy" { value = module.service.deployment_strategy }
output "ecs_service_arn" { value = module.service.ecs_service_arn }
output "bindings" { value = [for b in local.bindings : "${b.type}:${b.name}"] }
output "database_endpoint" { value = var.use_database ? module.db[0].endpoint : null }
