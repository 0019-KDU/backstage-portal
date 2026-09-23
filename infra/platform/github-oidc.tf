# ---------------------------------------------------------------------------
# github-oidc.tf — let GitHub Actions log in to AWS WITHOUT stored keys
#
# How it works:
#   1. A workflow asks GitHub for a signed OIDC token ("I am repo X, branch Y").
#   2. It sends the token to AWS STS: AssumeRoleWithWebIdentity.
#   3. AWS checks the signature against the provider below and the conditions
#      in the role's trust policy, then returns credentials valid ~1 hour.
# Nothing secret is stored in GitHub; a leaked token expires within the hour.
# ---------------------------------------------------------------------------
variable "github_owner" {
  description = "GitHub user/org whose repositories may deploy"
  type        = string
  default     = "0019-KDU"
}

variable "github_owner_id" {
  description = "Immutable numeric ID of github_owner (curl https://api.github.com/users/<owner> | jq .id)"
  type        = string
  default     = "112224823"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # Every resource a service stack creates must start with this prefix,
  # so the CI role below can only touch IDP resources.
  svc_prefix = "${var.name}-svc"
}

# GitHub as a trusted identity provider exists ONCE per AWS account.
# This account already had one (created 2026-05-26, outside this project),
# so we only READ it (data source) instead of creating/owning it:
# `terraform destroy` of this stack will never delete it.
# In a fresh account, replace this with a `resource` block:
#   resource "aws_iam_openid_connect_provider" "github" {
#     url            = "https://token.actions.githubusercontent.com"
#     client_id_list = ["sts.amazonaws.com"]
#   }
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# --- Trust policy: WHO may assume the role ---------------------------------
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    # The token must be meant for AWS STS...
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # ...and come from a repository owned by var.github_owner.
    # Forks and other people's repos are rejected.
    #
    # GitHub "immutable subject claims" (repos created after 2026-07-15):
    #   sub = repo:<owner>@<owner_id>/<repo>@<repo_id>:environment:dev
    # Pinning the numeric owner ID means a future account with the same NAME
    # (after a rename/deletion) can never assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@${var.github_owner_id}/*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.name}-github-actions"
  description          = "Assumed by GitHub Actions in ${var.github_owner}/* via OIDC"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

# --- Permission policy: WHAT the role may do --------------------------------
# Scoped by name prefix "devops94-idp-svc-*" wherever AWS supports it.
data "aws_iam_policy_document" "github_actions" {
  # Log in to ECR (this API has no resource-level scoping)
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Create repositories and push images, only devops94-idp-svc-* repos
  statement {
    sid     = "EcrServiceRepos"
    actions = ["ecr:*"]
    resources = [
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/${local.svc_prefix}-*"
    ]
  }

  # Task definitions cannot be scoped by ARN at registration time
  statement {
    sid = "EcsTaskDefinitions"
    actions = [
      "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition", "ecs:ListTaskDefinitions", "ecs:TagResource",
      "ecs:ListTagsForResource" # Terraform reads task-definition tags on refresh
    ]
    resources = ["*"]
  }

  # Create/update/delete services, only inside our cluster
  statement {
    sid = "EcsServicesInIdpCluster"
    actions = [
      "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
      "ecs:DescribeServices", "ecs:ListTasks", "ecs:DescribeTasks",
      "ecs:TagResource", "ecs:UntagResource", "ecs:ListTagsForResource",
      # AWS provider 6.x waits for a rollout (wait_for_steady_state) with these newer APIs
      "ecs:ListServiceDeployments", "ecs:DescribeServiceDeployments", "ecs:DescribeServiceRevisions"
    ]
    resources = [
      "arn:aws:ecs:${var.region}:${local.account_id}:service/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${var.region}:${local.account_id}:task/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${var.region}:${local.account_id}:service-deployment/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${var.region}:${local.account_id}:service-revision/${aws_ecs_cluster.this.name}/*",
      aws_ecs_cluster.this.arn
    ]
  }

  # Per-service IAM roles (task execution role + task role)
  statement {
    sid = "ServiceIamRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListInstanceProfilesForRole"
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.svc_prefix}-*"]
  }

  # ECS may only be handed our service roles
  statement {
    sid       = "PassServiceRolesToEcs"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.svc_prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Container log groups: /ecs/devops94-idp-svc-*
  statement {
    sid = "ServiceLogGroups"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource"
    ]
    resources = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/ecs/${local.svc_prefix}-*"]
  }

  # Target groups (names <= 32 chars) and routing rules on OUR listener only
  statement {
    sid = "LoadBalancerRouting"
    actions = [
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule", "elasticloadbalancing:SetRulePriorities",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.region}:${local.account_id}:targetgroup/d94-*/*",
      aws_lb_listener.http.arn,
      "arn:aws:elasticloadbalancing:${var.region}:${local.account_id}:listener-rule/app/${aws_lb.this.name}/*"
    ]
  }

  # Read-only lookups Terraform needs (VPC, subnets, SGs, ALB, log groups)
  statement {
    sid = "ReadOnlyDescribe"
    actions = [
      "ec2:Describe*", "elasticloadbalancing:Describe*",
      "logs:DescribeLogGroups", "ecs:DescribeClusters", "iam:GetOpenIDConnectProvider"
    ]
    resources = ["*"]
  }

  # Terraform state for service stacks: s3://<bucket>/services/*
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::devops94-idp-tfstate-${local.account_id}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["services/*"]
    }
  }
  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::devops94-idp-tfstate-${local.account_id}/services/*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.name}-github-actions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}

output "github_actions_role_arn" {
  description = "Put this in workflows: aws-actions/configure-aws-credentials role-to-assume"
  value       = aws_iam_role.github_actions.arn
}
