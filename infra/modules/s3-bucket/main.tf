# ---------------------------------------------------------------------------
# s3-bucket — a private bucket with safe defaults.
# Guardrails: all public access blocked · encryption at rest · HTTPS-only policy
#   · versioning (recover deleted/overwritten objects) · old versions expire after
#   30 days · incomplete uploads cleaned up · ACLs disabled (bucket owner enforced)
# ---------------------------------------------------------------------------
variable "name" {
  description = "Bucket purpose name (bucket becomes devops94-idp-<env>-<kind>-<name>-<account-id>)"
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
variable "versioning" {
  type    = bool
  default = true
}
variable "force_destroy" {
  description = "Allow deleting the bucket while it still contains objects"
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

data "aws_caller_identity" "current" {}

locals {
  bucket = "${var.platform_name}-${var.environment}-${var.kind}-${var.name}-${data.aws_caller_identity.current.account_id}"
  tags   = merge(var.tags, { resource = var.name, resource-type = "s3-bucket", environment = var.environment })
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    id     = "housekeeping"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}

output "bucket_name" { value = aws_s3_bucket.this.bucket }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
output "console_url" {
  value = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.this.bucket}?region=${aws_s3_bucket.this.region}"
}
