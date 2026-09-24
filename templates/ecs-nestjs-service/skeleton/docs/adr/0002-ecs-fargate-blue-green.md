# ADR 0002: ECS Fargate with blue/green deployments

**Status:** accepted

**Decision:** run on AWS ECS Fargate (no servers or Kubernetes to operate); use native ECS
blue/green deployments with a bake time in staging and prod, rolling deployments in dev.

**Why:** zero-downtime releases with an instant rollback window, and no extra deployment tool
(CodeDeploy is not needed since ECS added built-in blue/green in 2025).

**Consequences:** during a deployment both versions run (double capacity for the bake time),
and database migrations must be backward-compatible (expand → contract).
