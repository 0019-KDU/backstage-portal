# ---------------------------------------------------------------------------
# Account-wide CI identity: the IMAGE BUILD role.
# Builds happen once per commit on main; the same image is then promoted
# dev -> staging -> prod by the per-environment deploy roles
# (infra/modules/platform-env/deploy-role.tf).
#
# Trust: GitHub OIDC, repos of the owner (immutable owner id), branch main only.
# Scope: ECR repositories devops94-idp-svc-* and their Terraform state
#        (services/<name>/shared.tfstate). No access to any environment.
# ---------------------------------------------------------------------------
variable "github_owner" {
  type    = string
  default = "0019-KDU"
}

variable "github_owner_id" {
  description = "Immutable numeric ID of github_owner (curl https://api.github.com/users/<owner> | jq .id)"
  type        = string
  default     = "112224823"
}

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "devops94-idp-tfstate-${local.account_id}"
}

# Exists once per AWS account; this account already had it, so we only read it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "build_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@${var.github_owner_id}/*:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "build" {
  name                 = "${var.name}-build"
  description          = "GitHub Actions: build + push images to ECR (main branch only)"
  assume_role_policy   = data.aws_iam_policy_document.build_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "build" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "EcrServiceRepos"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.name}-svc-*"]
  }
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["services/*"]
    }
  }
  statement {
    sid       = "TechDocsPublishList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.techdocs.arn]
  }
  statement {
    sid       = "TechDocsPublish" # pipeline publishes each service's built docs
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.techdocs.arn}/*"]
  }
  statement {
    sid       = "SharedState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/services/*/shared.tfstate*"]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "${var.name}-build"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build.json
}

output "build_role_arn" { value = aws_iam_role.build.arn }
