# Getting started

## Prerequisites

Node.js 24, Docker, Git. No AWS access is needed for local development.

## Run locally

```bash
git clone git@github.com:0019-KDU/${{ values.name }}.git && cd ${{ values.name }}

# 1. A local PostgreSQL (same major version as AWS)
docker run -d --name ${{ values.name }}-db -p 5432:5432 \
  -e POSTGRES_USER=app -e POSTGRES_PASSWORD=app -e POSTGRES_DB=app postgres:17-alpine

# 2. Dependencies and a first run (migrations run automatically at startup)
npm ci
npm run build && npm start          # http://localhost:8080/
```

## Test

```bash
npm test            # unit tests: fast, no database
npm run test:e2e    # end-to-end: the real app against the local database
```

CI runs both on every pull request and push, with a fresh PostgreSQL container.

## Make a change

1. Branch from `main`, change code and tests.
2. Open a pull request: tests and security scans run and must pass.
3. Merge: the pipeline deploys to dev and staging automatically, then waits for approval
   before prod (see [Deployment](deployment.md)).
