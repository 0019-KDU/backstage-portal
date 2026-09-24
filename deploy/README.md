# Backstage production runbook (EC2)

```
Internet ──443/TLS──▶ Nginx (host) ──▶ 127.0.0.1:7007 Backstage (Docker, host network)
                                             ├──▶ PostgreSQL 127.0.0.1:5432 (host)
                                             └──▶ GitHub OAuth / API
Public: 22 (admin), 80 (ACME + redirect), 443.   Private: 7007, 5432.
```

| Piece | Location |
|---|---|
| Production config | `app-config.yaml` + `app-config.production.yaml` (no secrets) |
| Secrets | `/etc/backstage/backstage.env` (root:docker 0640, outside Git); template `deploy/backstage.env.example` |
| Container | `deploy/docker-compose.yml` (`restart: unless-stopped`, healthcheck) |
| Nginx | `deploy/nginx/backstage.conf.template` → `/etc/nginx/sites-available/backstage` |
| TLS | Now (no domain): self-signed cert for the public IP, `sudo deploy/scripts/enable-nginx-selfsigned.sh <ip>` → `/etc/ssl/backstage/` (valid 1 year, re-run to renew or after an IP change). Later (real domain): Let's Encrypt via `deploy/scripts/enable-nginx-site.sh <domain> <email>`, auto-renewed by `certbot.timer` |
| Backups | `backstage-db-backup.timer` → `/var/backups/backstage/*.dump` |
| GitHub users | `catalog/users.yaml` |

## Repository map (production structure)

| Repository | Contains | Owner |
|---|---|---|
| **backstage-portal** (this repo) | Backstage app, its config and deployment (Docker, Nginx, backups) | portal maintainers |
| [platform-infra](https://github.com/0019-KDU/platform-infra) | AWS account + dev/staging/prod environments, versioned Terraform modules | platform team |
| [platform-golden-paths](https://github.com/0019-KDU/platform-golden-paths) | reusable CI/CD pipelines + Backstage templates (versioned) | platform team |
| [platform-resources](https://github.com/0019-KDU/platform-resources) | self-service cloud resources requested in Backstage | platform team reviews |
| service repos (e.g. [shop-api](https://github.com/0019-KDU/shop-api)) | app code + its own `infra/` + 10-line pipeline pinned to a version | product teams |

Backstage reads templates from `platform-golden-paths/templates/all-templates.yaml` and
resources from `platform-resources/resources/*/*/*/catalog-info.yaml`.

## Deploy a new version

```bash
cd /opt/backstage/devops94-demo
yarn install --immutable && yarn tsc && yarn build:backend
TAG=$(date +%Y%m%d)-$(git rev-parse --short HEAD)
docker build . -f packages/backend/Dockerfile -t backstage-devops94:$TAG -t backstage-devops94:latest
docker compose -f deploy/docker-compose.yml up -d
deploy/scripts/healthcheck.sh --insecure https://52.66.252.27   # self-signed; drop --insecure with a real domain
```

Rollback: `docker tag backstage-devops94:<previous-tag> backstage-devops94:latest && docker compose -f deploy/docker-compose.yml up -d`.

After editing `/etc/backstage/backstage.env`: `docker compose -f deploy/docker-compose.yml up -d --force-recreate`.

## Logs

```bash
docker logs -f --since 15m backstage                          # all Backstage logs (JSON)
docker logs backstage 2>&1 | grep '"level":"error"'           # errors (startup, plugins, DB)
docker logs backstage 2>&1 | grep '"plugin":"auth"'           # authentication / sign-in
docker logs backstage 2>&1 | grep -iE 'knex|postgres|ECONNREFUSED|password authentication'  # database
docker logs backstage 2>&1 | grep '"type":"incomingRequest"' | grep -E '"status":(4|5)[0-9]{2}'  # HTTP errors
docker logs backstage 2>&1 | grep '"plugin":"catalog"'        # a specific plugin
sudo tail -f /var/log/nginx/backstage.access.log /var/log/nginx/backstage.error.log
sudo tail -f /var/log/postgresql/postgresql-18-main.log
journalctl -u docker -u nginx -u postgresql --since today
journalctl -u backstage-db-backup.service
```

Container logs are rotated by Docker (5 × 20 MB). Nginx logs by logrotate.

## Health

```bash
deploy/scripts/healthcheck.sh --insecure https://52.66.252.27   # self-signed; drop --insecure with a real domain
curl -s http://127.0.0.1:7007/.backstage/health/v1/readiness   # official root health service
docker inspect -f '{{.State.Health.Status}}' backstage
pg_isready -h 127.0.0.1
```

## Secrets → AWS Secrets Manager (later)

1. Store one JSON secret, e.g. `backstage/prod` = `{POSTGRES_PASSWORD, AUTH_GITHUB_CLIENT_ID, AUTH_GITHUB_CLIENT_SECRET, ...}` (KMS-encrypted).
2. Give the EC2 instance role `secretsmanager:GetSecretValue` on that ARN only.
3. Replace the env file with a pre-start step that renders it (`aws secretsmanager get-secret-value ... | jq`), or move to ECS where task definitions inject secrets natively.
4. With RDS, prefer RDS-managed master credentials in Secrets Manager with automatic rotation.

## Backups

- Daily `pg_dump --format=custom` at 02:30 UTC, verified with `pg_restore --list`, sha256 alongside. Nothing is ever deleted; prune old dumps manually.
- Dumps sit on the same EBS volume, so copy them off-host (e.g. `aws s3 cp` to a versioned, encrypted bucket) and/or enable EBS snapshots via AWS Data Lifecycle Manager.
- Restore test (into a scratch DB, never over the live one):
  `sudo -u postgres createdb backstage_restore_test && sudo -u postgres pg_restore -d backstage_restore_test /var/backups/backstage/<file>.dump`
- Production target: Amazon RDS for PostgreSQL (Multi-AZ) with automated backups + point-in-time recovery (retention 7–35 days), deletion protection, `ssl: require`. Only `POSTGRES_HOST` and the TLS CA config change.
