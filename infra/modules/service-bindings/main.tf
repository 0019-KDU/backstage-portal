# ---------------------------------------------------------------------------
# service-bindings — turn "this service uses resource X" into:
#   * app permissions (task role policy)      e.g. read/write on ONE bucket
#   * environment variables                   e.g. SHOP_IMAGES_BUCKET, REPORTS_DB_HOST
#   * secrets injected by ECS                 e.g. REPORTS_DB_PASSWORD (RDS-managed)
#
# Bindings are files in the service repo: infra/app/bindings/<env>/<type>-<name>.json
#   {"type":"s3","name":"shop-images","access":"read-write","env_prefix":"SHOP_IMAGES"}
#   {"type":"rds-postgres","name":"reports-db","env_prefix":"REPORTS_DB"}
# The resources themselves are requested via Backstage (repo platform-resources) and
# named devops94-idp-<env>-res-<name>.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "environment" {
  type = string
}

variable "bindings" {
  description = "List of {type, name, access?, env_prefix}"
  type = list(object({
    type       = string
    name       = string
    access     = optional(string, "read-write")
    env_prefix = string
  }))
  default = []
  validation {
    condition     = alltrue([for b in var.bindings : contains(["s3", "rds-postgres"], b.type)])
    error_message = "binding type must be s3 or rds-postgres."
  }
  validation {
    condition     = alltrue([for b in var.bindings : contains(["read", "read-write"], b.access)])
    error_message = "binding access must be read or read-write."
  }
}

variable "platform_name" {
  type    = string
  default = "devops94-idp"
}

data "aws_caller_identity" "current" {}

locals {
  env_prefix = "${var.platform_name}-${var.environment}"
  s3         = { for b in var.bindings : b.name => b if b.type == "s3" }
  rds        = { for b in var.bindings : b.name => b if b.type == "rds-postgres" }
  bucket     = { for n, b in local.s3 : n => "${local.env_prefix}-res-${n}-${data.aws_caller_identity.current.account_id}" }
}

# Databases must already exist (merge the resource request first)
data "aws_db_instance" "rds" {
  for_each               = local.rds
  db_instance_identifier = "${local.env_prefix}-res-${each.key}"
}

data "aws_iam_policy_document" "app" {
  count = length(local.s3) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = local.s3
    content {
      sid       = "List${replace(title(replace(statement.key, "-", " ")), " ", "")}"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = ["arn:aws:s3:::${local.bucket[statement.key]}"]
    }
  }
  dynamic "statement" {
    for_each = local.s3
    content {
      sid = "Objects${replace(title(replace(statement.key, "-", " ")), " ", "")}"
      actions = statement.value.access == "read" ? ["s3:GetObject"] : [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"
      ]
      resources = ["arn:aws:s3:::${local.bucket[statement.key]}/*"]
    }
  }
}

output "task_policy_json" {
  description = "Attach to the service's task role (ecs-service task_policy_json); empty when not needed"
  value       = length(local.s3) > 0 ? data.aws_iam_policy_document.app[0].json : ""
}

output "environment_variables" {
  value = merge(
    { for n, b in local.s3 : "${b.env_prefix}_BUCKET" => local.bucket[n] },
    merge([for n, b in local.rds : {
      "${b.env_prefix}_HOST" = data.aws_db_instance.rds[n].address
      "${b.env_prefix}_PORT" = tostring(data.aws_db_instance.rds[n].port)
      "${b.env_prefix}_NAME" = data.aws_db_instance.rds[n].db_name
      "${b.env_prefix}_USER" = data.aws_db_instance.rds[n].master_username
    }]...)
  )
}

output "secrets" {
  value = { for n, b in local.rds : "${b.env_prefix}_PASSWORD" => "${data.aws_db_instance.rds[n].master_user_secret[0].secret_arn}:password::" }
}

output "secret_arns" {
  value = [for n, b in local.rds : data.aws_db_instance.rds[n].master_user_secret[0].secret_arn]
}
