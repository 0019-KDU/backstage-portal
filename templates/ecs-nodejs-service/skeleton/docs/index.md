# ${{ values.name }}

${{ values.description }}

Created with the **DevOps94 IDP golden path** and running on
**AWS ECS Fargate**.

| | |
|---|---|
| Dev URL | <http://devops94-idp-alb-1896325251.ap-south-1.elb.amazonaws.com/dev/${{ values.name }}/> |
| Health check | `GET /dev/${{ values.name }}/health` → `{"status":"ok"}` |
| Runtime | ECS Fargate (Spot in dev), 0.25 vCPU / 512 MiB, port 8080 |
| Image registry | ECR `devops94-idp-svc-${{ values.name }}` (immutable tags `sha-<commit>`) |

## How a change reaches AWS

1. Push to `main`.
2. **Unit tests** and **security scans** (Gitleaks, Trivy) run in parallel.
3. The image is built, scanned by Trivy, pushed to ECR.
4. Terraform deploys a new task definition revision; ECS performs a rolling update and
   **rolls back automatically** if the new tasks are unhealthy.
5. A smoke test calls the service through the load balancer.

The pipeline itself lives in the platform repository
([ecs-service.yml](https://github.com/0019-KDU/idp-platform/blob/main/.github/workflows/ecs-service.yml)),
so improvements reach every service automatically.

## API

| Method | Path | Response |
|---|---|---|
| GET | `/` | service, environment, running version |
| GET | `/health` | `{"status":"ok"}` |
