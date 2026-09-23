# ${{ values.name }}

${{ values.description }} (Node.js on ECS Fargate), deployed by the
[golden-path pipeline](https://github.com/0019-KDU/idp-platform/blob/main/.github/workflows/ecs-service.yml).

| | |
|---|---|
| Run tests | `npm test` |
| Run locally | `docker build -t ${{ values.name }}:local . && docker run -p 8080:8080 ${{ values.name }}:local` |
| Deploy | push to `main` (tests → security scan → build → image scan → ECR → ECS dev) |
| Infrastructure | `infra/` → module `ecs-service` from idp-platform |
