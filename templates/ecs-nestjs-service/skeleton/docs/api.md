# API

Base URL: `<environment URL>/` (see [Overview](index.md)). JSON in, JSON out.

| Method | Path | Description | Success |
|---|---|---|---|
| GET | `/` | Service, environment, running version | 200 |
| GET | `/health` | Liveness (used by the load balancer) | 200 `{"status":"ok"}` |
| GET | `/ready` | Readiness: database reachable | 200 / 503 |
| POST | `/products` | Create a product | 201 |
| GET | `/products` | List the latest 100 products | 200 |
| GET | `/products/{id}` | Get one product | 200 / 404 |
| POST | `/orders` | Place an order (price taken from the product) | 201 / 400 / 404 |
| GET | `/orders` | List the latest 100 orders | 200 |

## Examples

```bash
BASE=http://devops94-idp-dev-alb-754517378.ap-south-1.elb.amazonaws.com/${{ values.name }}

curl -s -X POST $BASE/products -H 'content-type: application/json' \
  -d '{"name":"Green tea","priceCents":450}'
# {"id":"<uuid>","name":"Green tea","priceCents":450,"createdAt":"..."}

curl -s -X POST $BASE/orders -H 'content-type: application/json' \
  -d '{"productId":"<uuid>","quantity":2}'
# {"id":"<uuid>","productId":"<uuid>","quantity":2,"totalCents":900,"createdAt":"..."}
```

## Errors

NestJS standard error body: `{"statusCode":400,"message":"quantity must be >= 1","error":"Bad Request"}`.

| Status | When |
|---|---|
| 400 | Invalid input (missing name, negative price, quantity < 1, invalid UUID) |
| 404 | Unknown product or path |
| 503 | `/ready` when the database is unreachable |
