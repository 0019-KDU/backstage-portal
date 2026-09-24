# Image repository for ${{ values.name }}: ONE repo for all environments
# (build once, promote the same image dev -> staging -> prod).
# Applied by the pipeline's build job (role devops94-idp-build).
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
    key          = "services/${{ values.name }}/shared.tfstate"
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
      component  = "${{ values.name }}"
      owner      = "${{ values.owner }}"
      stack      = "service-${{ values.name }}-shared"
      managed-by = "terraform"
    }
  }
}

resource "aws_ecr_repository" "this" {
  name                 = "devops94-idp-svc-${{ values.name }}"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

output "repository_url" { value = aws_ecr_repository.this.repository_url }
