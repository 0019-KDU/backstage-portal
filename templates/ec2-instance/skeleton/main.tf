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
    key          = "resources/ec2-instance/${{ values.name }}/terraform.tfstate"
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
      stack      = "resource-ec2-instance-${{ values.name }}"
      managed-by = "terraform"
    }
  }
}

module "this" {
  source         = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/ec2-instance?ref=main"
  name           = "${{ values.name }}"
  instance_type  = "${{ values.instanceType }}"
  root_volume_gb = ${{ values.rootVolume }}
  tags = {
    owner        = "${{ values.owner }}"
    component    = "${{ values.component }}"
    requested-by = "${{ values.requester }}"
  }
}

output "instance_id" { value = module.this.instance_id }
output "private_ip" { value = module.this.private_ip }
output "session_manager_url" { value = module.this.session_manager_url }
output "console_url" { value = module.this.console_url }
