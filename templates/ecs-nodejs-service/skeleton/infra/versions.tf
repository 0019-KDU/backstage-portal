terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Each service has its own state file under services/ (the CI role may only write there)
  backend "s3" {
    bucket       = "devops94-idp-tfstate-697502032879"
    key          = "services/${{ values.name }}/terraform.tfstate"
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
      stack      = "service-${{ values.name }}"
      managed-by = "terraform"
    }
  }
}
