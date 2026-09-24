# Requested in Backstage by ${{ values.requester }}, owner ${{ values.owner }}.
# Managed by the platform-resources pipeline: edit only via pull request.
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
    key          = "resources/rds-postgres/${{ values.environment }}/${{ values.name }}/terraform.tfstate"
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
      stack      = "resource-rds-postgres-${{ values.name }}"
      managed-by = "terraform"
    }
  }
}

module "this" {
  source               = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/rds-postgres?ref=main"
  environment          = "${{ values.environment }}"
  name                 = "${{ values.name }}"
  instance_class       = "${{ values.instanceClass }}"
  allocated_storage_gb = ${{ values.storage }}
  tags = {
    owner        = "${{ values.owner }}"
    component    = "${{ (values.component or '').split('/') | last }}"
    requested-by = "${{ values.requester }}"
  }
}

output "endpoint" { value = module.this.endpoint }
output "port" { value = module.this.port }
output "database_name" { value = module.this.database_name }
output "username" { value = module.this.username }
output "master_user_secret_arn" { value = module.this.master_user_secret_arn }
output "console_url" { value = module.this.console_url }
