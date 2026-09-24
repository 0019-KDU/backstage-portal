# ---------------------------------------------------------------------------
# backstage-iam — what the Backstage server itself may read in AWS.
# Attached to the EC2 instance role devops94-idp-ec2 (created in the console).
# Read-only: cost data for Cost Insights and ECS status for the ECS tab.
# Once the platform is no longer being built from this server, the broad
# devops94-idp-bootstrap policy can be detached and only this one kept.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "devops94-idp-tfstate-697502032879"
    key          = "backstage-iam/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      project    = "devops94-idp"
      stack      = "backstage-iam"
      managed-by = "terraform"
    }
  }
}

data "aws_iam_role" "backstage" {
  name = "devops94-idp-ec2"
}

data "aws_iam_policy_document" "backstage_read" {
  statement {
    sid       = "CostInsights" # Cost Explorer has no resource-level permissions
    actions   = ["ce:GetCostAndUsage"]
    resources = ["*"]
  }
  statement {
    sid = "EcsPluginRead" # @aws/amazon-ecs-plugin-for-backstage-backend
    actions = [
      "ecs:DescribeServices", "ecs:ListTasks", "ecs:DescribeTasks", "ecs:DescribeClusters"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "backstage_read" {
  name        = "devops94-idp-backstage-read"
  description = "Read-only AWS access for the Backstage server (Cost Insights, ECS status)"
  policy      = data.aws_iam_policy_document.backstage_read.json
}

resource "aws_iam_role_policy_attachment" "backstage_read" {
  role       = data.aws_iam_role.backstage.name
  policy_arn = aws_iam_policy.backstage_read.arn
}

output "policy_arn" { value = aws_iam_policy.backstage_read.arn }
