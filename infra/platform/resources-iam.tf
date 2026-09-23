# ---------------------------------------------------------------------------
# resources-iam.tf — two roles for the self-service resources pipeline
# (repo 0019-KDU/platform-resources):
#
#   Pull request  ─► devops94-idp-resources-plan   read-only: `terraform plan`
#   Merge to main ─► devops94-idp-resources-apply  create/change/delete, ONLY
#                    resources named devops94-idp-res-* (RDS, S3, EC2 + its role)
#
# A PR can never change AWS: only code that was reviewed and merged gets the apply role.
# ---------------------------------------------------------------------------
locals {
  res_prefix     = "${var.name}-res"
  resources_repo = "repo:${var.github_owner}@${var.github_owner_id}/platform-resources@*"
  state_bucket   = "devops94-idp-tfstate-${local.account_id}"
}

data "aws_iam_policy_document" "resources_plan_trust" {
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
      values   = ["${local.resources_repo}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "resources_apply_trust" {
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
      values   = ["${local.resources_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "resources_plan" {
  name               = "${var.name}-resources-plan"
  description        = "terraform plan for platform-resources pull requests (read-only)"
  assume_role_policy = data.aws_iam_policy_document.resources_plan_trust.json
}

resource "aws_iam_role" "resources_apply" {
  name               = "${var.name}-resources-apply"
  description        = "terraform apply for platform-resources main branch (devops94-idp-res-* only)"
  assume_role_policy = data.aws_iam_policy_document.resources_apply_trust.json
}

# --- Shared by both: read everything Terraform needs to compute a plan -------
data "aws_iam_policy_document" "resources_read" {
  statement {
    sid = "Describe"
    actions = [
      "ec2:Describe*", "rds:Describe*", "rds:ListTagsForResource",
      "secretsmanager:DescribeSecret", "kms:DescribeKey"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "LatestAmazonLinuxAmi"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}::parameter/aws/service/ami-amazon-linux-latest/*"]
  }
  statement {
    sid       = "ReadResourceBuckets"
    actions   = ["s3:Get*", "s3:List*"]
    resources = ["arn:aws:s3:::${local.res_prefix}-*", "arn:aws:s3:::${local.res_prefix}-*/*"]
  }
  statement {
    sid = "ReadResourceIam"
    actions = [
      "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:GetInstanceProfile"
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.res_prefix}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${local.res_prefix}-*"
    ]
  }
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["resources/*"]
    }
  }
  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/resources/*"]
  }
  statement {
    sid       = "StateLock" # plan takes the lock too (writes <key>.tflock)
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/resources/*.tflock"]
  }
}

resource "aws_iam_role_policy" "resources_plan" {
  name   = "${var.name}-resources-plan"
  role   = aws_iam_role.resources_plan.id
  policy = data.aws_iam_policy_document.resources_read.json
}

# --- Apply only: create/change/delete devops94-idp-res-* resources -----------
data "aws_iam_policy_document" "resources_write" {
  source_policy_documents = [data.aws_iam_policy_document.resources_read.json]

  statement {
    sid       = "StateWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/resources/*"]
  }

  # RDS PostgreSQL instances + their subnet groups
  statement {
    sid     = "Rds"
    actions = ["rds:*"]
    resources = [
      "arn:aws:rds:${var.region}:${local.account_id}:db:${local.res_prefix}-*",
      "arn:aws:rds:${var.region}:${local.account_id}:subgrp:${local.res_prefix}-*",
      "arn:aws:rds:${var.region}:${local.account_id}:pg:default*",
      "arn:aws:rds:${var.region}:${local.account_id}:og:default*"
    ]
  }
  # RDS stores the master password in Secrets Manager (manage_master_user_password)
  statement {
    sid       = "RdsManagedSecret"
    actions   = ["secretsmanager:CreateSecret", "secretsmanager:TagResource", "secretsmanager:RotateSecret", "secretsmanager:DeleteSecret"]
    resources = ["arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:rds!*"]
  }
  statement {
    sid       = "RdsServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["rds.amazonaws.com"]
    }
  }

  # Security groups (for databases/instances), only inside the platform VPC
  statement {
    sid = "SecurityGroups"
    actions = [
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules", "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress", "ec2:CreateTags", "ec2:DeleteTags"
    ]
    resources = ["*"]
  }

  # EC2 instances: launch anything tagged for the IDP; manage only IDP-tagged instances
  statement {
    sid       = "Ec2Launch"
    actions   = ["ec2:RunInstances"]
    resources = ["*"]
  }
  statement {
    sid = "Ec2ManageIdpInstances"
    actions = [
      "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances",
      "ec2:RebootInstances", "ec2:ModifyInstanceAttribute", "ec2:ModifyInstanceMetadataOptions"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/project"
      values   = ["devops94-idp"]
    }
  }

  # Per-instance IAM role + instance profile (Systems Manager access only)
  statement {
    sid = "InstanceRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:UntagRole",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:TagInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.res_prefix}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${local.res_prefix}-*"
    ]
  }
  statement {
    sid       = "InstanceRoleSsmPolicyOnly"
    actions   = ["iam:AttachRolePolicy"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.res_prefix}-*"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    }
  }
  statement {
    sid       = "PassInstanceRoleToEc2"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.res_prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  # S3 buckets named devops94-idp-res-*
  statement {
    sid       = "ResourceBuckets"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${local.res_prefix}-*", "arn:aws:s3:::${local.res_prefix}-*/*"]
  }
}

resource "aws_iam_role_policy" "resources_apply" {
  name   = "${var.name}-resources-apply"
  role   = aws_iam_role.resources_apply.id
  policy = data.aws_iam_policy_document.resources_write.json
}
