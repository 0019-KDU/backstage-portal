# ADR 0001: Modular monolith

**Status:** accepted · **Context:** new startup product, one team, fast iteration.

**Decision:** one NestJS application, split into modules by business capability, with strict
module boundaries (own tables, exported services only).

**Why:** one deployable is faster to build, cheaper to run and simpler to operate than
microservices; clear module boundaries keep the option to extract a service later.

**Consequences:** all modules scale together; a module that needs independent scaling or
release cadence is extracted into its own service (its boundary is already an API).
