# Architecture

## Context

```
 Clients ──HTTP──► AWS ALB (per environment) ──/${{ values.name }}/*──► ECS Fargate tasks (this service)
                                                                        │
                                                                        ├─► PostgreSQL (RDS, private subnets, TLS)
                                                                        └─► CloudWatch Logs
```

## Modular monolith

One deployable application; each **business capability is a module** with its own code,
tables and public service.

```
src/
  main.ts                 bootstrap: base path, JSON logger, graceful shutdown
  app.module.ts           wires modules + database
  common/                 cross-cutting: logging, request logging
  database/               connection settings + migrations
  modules/
    health/               /health (liveness), /ready (database), / (info)
    products/             table products · ProductsService (exported)
    orders/               table orders   · OrdersService (uses ProductsService)
```

### Module rules

| Rule | Why |
|---|---|
| A module owns its tables; no other module reads or writes them | Modules can change their schema independently |
| Modules talk through **exported services**, never repositories | One clear, testable contract per module |
| No database foreign keys across modules (store ids) | Makes a later split into a separate service possible |
| One folder per capability under `src/modules` | Ownership and code review stay clear as the team grows |

**When to extract a module into its own service:** it needs to scale very differently, it is
owned by a separate team with its own release cadence, or it has different security/compliance
needs. Until then, the monolith is cheaper to run and simpler to change
(see [ADR 0001](adr/0001-modular-monolith.md)).

## Request flow

1. The ALB forwards `/${{ values.name }}/*` to a healthy task (health check: `GET /${{ values.name }}/health`).
2. NestJS routes under the global prefix `/${{ values.name }}` (from `BASE_PATH`).
3. Every request except health checks is logged as one JSON line.
4. Database access through TypeORM; the connection uses TLS verified against the RDS CA bundle.
