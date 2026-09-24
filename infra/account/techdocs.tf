# ---------------------------------------------------------------------------
# TechDocs storage (Backstage "recommended deployment"): docs are BUILT IN CI
# (each service pipeline) and PUBLISHED here; Backstage only reads them.
#   write: devops94-idp-build (pipeline, main branch)
#   read:  Backstage server role (infra/backstage-iam)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "techdocs" {
  bucket = "${var.name}-techdocs-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "techdocs" {
  bucket                  = aws_s3_bucket.techdocs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "techdocs" {
  bucket = aws_s3_bucket.techdocs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

output "techdocs_bucket" { value = aws_s3_bucket.techdocs.bucket }
