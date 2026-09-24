# Platform for the "prod" environment (own Terraform state: platform/prod.tfstate)
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
    key          = "platform/prod.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      project     = "devops94-idp"
      environment = "prod"
      stack       = "platform-prod"
      managed-by  = "terraform"
    }
  }
}

module "platform" {
  source      = "../../modules/platform-env"
  environment = "prod"
  vpc_cidr    = "10.22.0.0/16"
}

output "base_url" { value = module.platform.base_url }
output "ecs_cluster_name" { value = module.platform.ecs_cluster_name }
output "deploy_role_arn" { value = module.platform.deploy_role_arn }
output "ecs_infrastructure_role_arn" { value = module.platform.ecs_infrastructure_role_arn }
