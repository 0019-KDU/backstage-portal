# ---------------------------------------------------------------------------
# versions.tf — which Terraform/provider versions to use and WHERE state lives
# ---------------------------------------------------------------------------
terraform {
  # use_lockfile (S3-native state locking) needs Terraform >= 1.10
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # any 6.x, never an automatic jump to 7.x (breaking changes)
    }
  }

  # State is stored in the bucket you created by hand in Lesson 2.
  # "key" is the path of this stack's state file inside the bucket.
  backend "s3" {
    bucket       = "devops94-idp-tfstate-697502032879"
    key          = "platform/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # writes a .tflock object so two applies can't run at once
  }
}

provider "aws" {
  region = var.region

  # Added to EVERY resource this stack creates: ownership + cost reports.
  default_tags {
    tags = {
      project    = "devops94-idp"
      stack      = "platform"
      managed-by = "terraform"
    }
  }
}
