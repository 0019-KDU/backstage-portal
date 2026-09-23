# Module: ecs-service

The golden-path infrastructure contract for ONE service in ONE environment on the
shared DevOps94 IDP platform (`infra/platform`).

Creates: CloudWatch log group · execution + task IAM roles · ALB target group ·
path-based listener rule `/<environment>/<name>/*` · Fargate task definition ·
ECS service (deployment circuit breaker with automatic rollback).

It does NOT create the ECR repository (one repo is shared by all environments of a
service; the calling stack owns it) and never touches the platform itself.

Contract for the container: listen on port 8080, serve `GET <BASE_PATH>/health`
with HTTP 200, log to stdout. `BASE_PATH` is injected (`/<environment>/<name>`).

```hcl
module "dev" {
  source      = "git::https://github.com/0019-KDU/idp-platform.git//infra/modules/ecs-service?ref=main"
  name        = "reference-api"
  environment = "dev"
  image       = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
}
```
