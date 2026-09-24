# Deployment

```
push to main
  ├─ Tests (unit + e2e with PostgreSQL) ── Security scan (Gitleaks, Trivy)
  ├─ Publish TechDocs (these pages)
  ├─ Build image ONCE → Trivy image scan → ECR  (tag sha-<commit>, immutable)
  ├─ dev      rolling       automatic
  ├─ staging  blue/green    automatic after dev
  └─ prod     blue/green    waits for approval ("Review deployments" in GitHub Actions)
```

The **same image** moves through all environments; it is never rebuilt.

## Blue/green (staging, prod)

1. ECS starts the complete new version (**green**) next to the current one (**blue**).
2. Green must pass the load balancer health checks.
3. ECS switches the production listener rule to green.
4. **Bake time** (prod: 10 min): blue stays running so traffic can switch back instantly.
5. Blue is stopped.

If green never becomes healthy, the **deployment circuit breaker** rolls back automatically and
the pipeline job fails.

## Approving a production deployment

GitHub → repository → **Actions** → the running pipeline → **Review deployments** → tick
**prod** → **Approve and deploy**. Only approved reviewers can do this, and only commits on
`main` can deploy.

## Rolling back

| Situation | Action |
|---|---|
| During the bake time | Stop the deployment: ECS moves traffic back to blue immediately<br>`aws ecs list-service-deployments --cluster devops94-idp-prod-cluster --service ${{ values.name }}`<br>`aws ecs stop-service-deployment --service-deployment-arn <arn> --stop-type ROLLBACK` |
| After the bake time | `git revert <commit>` and push; the pipeline ships the previous code as a new image |
| Emergency (revert is slow) | GitHub Actions → a **previous successful run** → *Re-run* its `prod` job: redeploys that older, immutable image |

## Autoscaling

Target tracking keeps average **CPU near 60 %** (memory 75 %) between `min_tasks` and
`max_tasks`. Scale-out reacts within about a minute; scale-in waits 3 minutes to avoid flapping.
