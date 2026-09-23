# ---------------------------------------------------------------------------
# ${{ values.name }} infrastructure
#   - ONE image repository (shared by all environments: build once, promote the same image)
#   - one module call per environment
# ---------------------------------------------------------------------------
variable "image_tag" {
  description = "Image tag to deploy (CI passes the git commit SHA)"
  type        = string
}

locals {
  name = "${{ values.name }}"
  tags = {
    owner  = "${{ values.owner }}" # Backstage owner (entity ref)
    system = "idp-demo"
  }
}

resource "aws_ecr_repository" "this" {
  name                 = "devops94-idp-svc-${local.name}"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten -> deploys are reproducible
  image_scanning_configuration {
    scan_on_push = true # ECR basic vulnerability scan on every push
  }
  tags = local.tags
}

# Keep the registry small: expire all but the newest 20 images
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20 }
      action       = { type = "expire" }
    }]
  })
}

module "dev" {
  # While learning we track main; Lesson 6 pins this to a release tag.
  source      = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/ecs-service?ref=main"
  name        = local.name
  environment = "dev"
  image       = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
  tags        = local.tags
  # Shown by the app in every response: which build is running
  environment_variables = { APP_VERSION = var.image_tag }
}

output "ecr_repository_url" { value = aws_ecr_repository.this.repository_url }
output "dev_url" { value = module.dev.url }
output "dev_log_group" { value = module.dev.log_group_name }
