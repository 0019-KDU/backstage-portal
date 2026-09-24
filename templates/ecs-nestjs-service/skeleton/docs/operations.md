# Operations runbook

## Health

| Check | Command / place |
|---|---|
| Liveness | `curl <env-url>/health` → `{"status":"ok"}` |
| Database | `curl <env-url>/ready` → `{"status":"ready","database":"ok"}` |
| Running version | `curl <env-url>/` → `"version":"sha-…"` |
| ECS status | Backstage → **Amazon ECS** tab (prod), or the ECS console link in the catalog |

## Logs

```bash
aws logs tail /ecs/devops94-idp-prod-svc-${{ values.name }} --follow
aws logs tail /ecs/devops94-idp-prod-svc-${{ values.name }} --since 1h --filter-pattern '{ $.level = "error" }'
aws logs tail /ecs/devops94-idp-prod-svc-${{ values.name }} --since 1h --filter-pattern '{ $.status >= 500 }'
```

Every line is JSON: `time, level, msg, service, environment, version` (+ `method, path, status, ms` for requests).

## Common incidents

| Symptom | Likely cause | What to do |
|---|---|---|
| 503 from the ALB, no healthy targets | tasks crash at start | Logs: look for the startup error (config, migration, database) |
| `/ready` returns 503 | database unreachable or overloaded | RDS console: status, CPU, connections; check the security group |
| Deployment stuck, pipeline waiting | green tasks unhealthy | Logs of the new tasks; the circuit breaker will roll back |
| Slow responses under load | CPU saturated | Autoscaling adds tasks up to `max_tasks`; raise it or `cpu` in `env/prod.tfvars` |
| Pipeline fails with `AccessDenied` | the environment's deploy role lacks a permission | Platform team: `infra/modules/platform-env/deploy-role.tf` |

## Scaling by hand (temporary)

```bash
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --resource-id service/devops94-idp-prod-cluster/${{ values.name }} \
  --scalable-dimension ecs:service:DesiredCount --min-capacity 4 --max-capacity 10
```

Make permanent changes in `infra/app/env/prod.tfvars` (the pipeline would otherwise reset them).

## Cost

Backstage → this component → **Costs** tab (tag `component=${{ values.name }}`, all environments).
