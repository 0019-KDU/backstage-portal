# Architecture: modular monolith

One deployable application, split into **modules** that each own one business capability.

```
src/modules/
  products/   entity + table `products` + ProductsService (exported)
  orders/     entity + table `orders`   + OrdersService  (uses ProductsService)
  health/     /health, /ready
```

## Rules that keep it modular

1. A module owns its tables. **No other module queries them**; there are no cross-module foreign keys.
2. Modules talk only through **exported services** (`exports: [ProductsService]`), never repositories.
3. New capability = new folder in `src/modules` + a migration.
4. Migrations must be **backward-compatible** (expand, then contract): during a blue/green deployment
   the old and the new version run at the same time against the same database.

When one module needs to scale or deploy on its own schedule, its service boundary is
already clean enough to extract it into a separate service.
