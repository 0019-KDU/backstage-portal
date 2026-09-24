# ${{ values.name }}

${{ values.description }}

| | |
|---|---|
| **Type** | TypeScript NestJS **modular monolith** (REST API) |
| **Owner** | `${{ values.owner }}` |
| **Runtime** | AWS ECS Fargate, `ap-south-1` |
| **Database** | PostgreSQL 17 (Amazon RDS), one per environment |
| **Delivery** | `main` → build once → dev → staging → **approval** → prod |
| **Source** | <https://github.com/0019-KDU/${{ values.name }}> |

## Environments

| Environment | URL | Deployment | Capacity |
|---|---|---|---|
| dev | <http://devops94-idp-dev-alb-754517378.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | rolling, automatic | 1–2 tasks, Fargate Spot |
| staging | <http://devops94-idp-staging-alb-575975725.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | blue/green, automatic | 1–2 tasks |
| prod | <http://devops94-idp-prod-alb-793088738.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | blue/green, **approval required** | 2–6 tasks, 2 AZs |

## Where to look

| I want to… | Go to |
|---|---|
| Run it on my laptop | [Getting started](getting-started.md) |
| Understand the code structure | [Architecture](architecture.md) |
| Call the API | [API](api.md) |
| Change a setting or secret | [Configuration](configuration.md) |
| Change the database schema | [Database](database.md) |
| Ship a change / roll back | [Deployment](deployment.md) |
| Handle an incident | [Operations runbook](operations.md) |
| Know why it is built this way | [Decisions](adr/0001-modular-monolith.md) |
