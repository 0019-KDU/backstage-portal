# Module: ecs-service

One service in ONE environment (dev | staging | prod) on that environment's platform
(`infra/modules/platform-env`): log group · execution + task roles · target group(s) ·
path rule `/<name>/*` on the environment's ALB · Fargate task definition · ECS service ·
autoscaling (CPU + memory target tracking).

| | ROLLING (dev default) | BLUE_GREEN (staging/prod) |
|---|---|---|
| How | Replace tasks gradually | Start the complete new version, switch traffic, keep the old one for `bake_time_minutes` |
| Rollback | Circuit breaker | Circuit breaker + instant switch back during bake time |
| Cost during deploy | +1 task | Double tasks for the bake time |

Container contract: port 8080, `GET <BASE_PATH>/health` → 200, JSON logs to stdout.
Secrets (`secrets` + `secret_arns`) are injected by ECS at start from Secrets Manager.
