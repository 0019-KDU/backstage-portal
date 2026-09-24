# Environments & deployments

```
git push main
  ├─ tests (unit + e2e with PostgreSQL) · Gitleaks · Trivy
  ├─ build image once → Trivy image scan → ECR (sha-<commit>)
  ├─ dev      ROLLING      automatic
  ├─ staging  BLUE/GREEN   automatic after dev
  └─ prod     BLUE/GREEN   waits for approval (GitHub Environment "prod"), 10 min bake time
```

| | dev | staging | prod |
|---|---|---|---|
| Deployment | rolling | blue/green (3 min bake) | blue/green (10 min bake) |
| Tasks (autoscaling) | 1–2, Spot | 1–2 | 2–6 across 2 AZs |
| Size | 0.25 vCPU / 0.5 GB | 0.25 vCPU / 0.5 GB | 0.5 vCPU / 1 GB |
| Database | db.t4g.micro, 1-day backups | db.t4g.micro, 1-day backups | db.t4g.micro, 7-day backups, deletion protection |

**Blue/green**: ECS starts the complete new version (green) next to the current one (blue), checks
it is healthy, switches the load balancer, and keeps blue running for the bake time. If the new
version fails, ECS switches back automatically.

**Autoscaling** keeps average CPU near 60 % (memory 75 %) between the min and max task counts.

**Logs**: `aws logs tail /ecs/devops94-idp-<env>-svc-${{ values.name }} --follow`
