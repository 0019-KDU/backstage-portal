# ${{ values.name }}

${{ values.description }}

TypeScript **NestJS modular monolith** on **AWS ECS Fargate** with **PostgreSQL**, created
with the DevOps94 IDP golden path.

| Environment | URL | Deploys |
|---|---|---|
| dev | <http://devops94-idp-dev-alb-754517378.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | every push to `main`, rolling |
| staging | <http://devops94-idp-staging-alb-575975725.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | automatically after dev, blue/green |
| prod | <http://devops94-idp-prod-alb-793088738.ap-south-1.elb.amazonaws.com/${{ values.name }}/> | after **approval**, blue/green with 10 min bake time |

## API

| Method | Path | |
|---|---|---|
| GET | `/` | service, environment, running version |
| GET | `/health` | liveness (load balancer) |
| GET | `/ready` | readiness: database reachable |
| GET/POST | `/products` | products module |
| GET/POST | `/orders` | orders module (uses products through its service) |

## Develop locally

```bash
docker run -d --name pg -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app -e POSTGRES_DB=app -p 5432:5432 postgres:17-alpine
npm ci
npm test            # unit tests
npm run test:e2e    # end-to-end against the local database
npm run build && npm start
```
