# ---------------------------------------------------------------------------
# CI deploy role for THIS environment.
#   Who:  only a GitHub Actions job that runs in the GitHub Environment named
#         <environment> in a repo of the owner (immutable owner id).
#         For prod that environment requires a human approval, so no code can
#         reach prod without the button click.
#   What: only resources named devops94-idp-<env>-svc-* in this environment.
# ---------------------------------------------------------------------------
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_trust" {
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
      values   = ["repo:${var.github_owner}@${var.github_owner_id}/*:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.prefix}-deploy"
  description          = "GitHub Actions deploys to ${var.environment} (GitHub Environment '${var.environment}' only)"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  # --- Terraform state: services/<name>/<env>.tfstate only ------------------
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["services/*"]
    }
  }
  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/services/*/${var.environment}.tfstate*"]
  }

  # --- ECS: services in this environment's cluster -------------------------
  statement {
    sid = "EcsTaskDefinitions" # no resource-level scoping at registration
    actions = [
      "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions", "ecs:TagResource", "ecs:ListTagsForResource"
    ]
    resources = ["*"]
  }
  statement {
    sid = "EcsServices"
    actions = [
      "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService", "ecs:DescribeServices",
      "ecs:ListTasks", "ecs:DescribeTasks", "ecs:TagResource", "ecs:UntagResource",
      "ecs:ListTagsForResource", "ecs:ListServiceDeployments", "ecs:DescribeServiceDeployments",
      "ecs:DescribeServiceRevisions", "ecs:StopServiceDeployment"
    ]
    resources = [
      aws_ecs_cluster.this.arn,
      "arn:aws:ecs:${local.region}:${local.account_id}:service/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${local.region}:${local.account_id}:task/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${local.region}:${local.account_id}:service-deployment/${aws_ecs_cluster.this.name}/*",
      "arn:aws:ecs:${local.region}:${local.account_id}:service-revision/${aws_ecs_cluster.this.name}/*"
    ]
  }

  # --- IAM: per-service task/execution roles; pass roles to ECS -------------
  statement {
    sid = "ServiceRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListInstanceProfilesForRole"
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.svc_prefix}-*"]
  }
  statement {
    sid       = "PassServiceRolesToTasks"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.svc_prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
  statement {
    sid       = "PassBlueGreenRoleToEcs"
    actions   = ["iam:PassRole", "iam:GetRole"]
    resources = [aws_iam_role.ecs_infrastructure.arn]
  }

  # --- Logs -------------------------------------------------------------
  statement {
    sid = "ServiceLogGroups"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource"
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${local.svc_prefix}-*"]
  }

  # --- Load balancer: blue/green target groups + rules on THIS listener ---
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
      "arn:aws:elasticloadbalancing:${local.region}:${local.account_id}:targetgroup/${local.tg_prefix}-*/*",
      aws_lb_listener.http.arn,
      "arn:aws:elasticloadbalancing:${local.region}:${local.account_id}:listener-rule/app/${aws_lb.this.name}/*"
    ]
  }

  # --- Autoscaling (target tracking creates CloudWatch alarms) -------------
  statement {
    sid = "Autoscaling"
    actions = [
      "application-autoscaling:RegisterScalableTarget", "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy", "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:Describe*", "application-autoscaling:TagResource",
      "application-autoscaling:ListTagsForResource"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "AutoscalingAlarms"
    actions   = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms"]
    resources = ["*"]
  }
  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["ecs.application-autoscaling.amazonaws.com", "rds.amazonaws.com", "ecs.amazonaws.com"]
    }
  }

  # --- Service databases (RDS PostgreSQL) -----------------------------------
  statement {
    sid     = "ServiceDatabases"
    actions = ["rds:*"]
    resources = [
      "arn:aws:rds:${local.region}:${local.account_id}:db:${local.svc_prefix}-*",
      "arn:aws:rds:${local.region}:${local.account_id}:subgrp:${local.svc_prefix}-*",
      "arn:aws:rds:${local.region}:${local.account_id}:pg:default*",
      "arn:aws:rds:${local.region}:${local.account_id}:og:default*",
      "arn:aws:rds:${local.region}:${local.account_id}:secgrp:*"
    ]
  }
  statement {
    sid       = "RdsManagedPassword" # RDS keeps the master password in Secrets Manager
    actions   = ["secretsmanager:CreateSecret", "secretsmanager:TagResource", "secretsmanager:RotateSecret", "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:rds!*"]
  }

  # --- Read-only lookups ------------------------------------------------------
  statement {
    sid = "ReadOnly"
    actions = [
      "ec2:Describe*", "elasticloadbalancing:Describe*", "ecs:DescribeClusters",
      "logs:DescribeLogGroups", "rds:Describe*", "kms:DescribeKey",
      "iam:GetOpenIDConnectProvider", "ecr:DescribeRepositories", "ecr:DescribeImages"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${local.prefix}-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
