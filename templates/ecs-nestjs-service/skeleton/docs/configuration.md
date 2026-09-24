# Configuration

All configuration is **environment variables**, set by the platform. Nothing is read from files
in the image, and no secret is ever stored in Git, the image or Terraform code.

| Variable | Source | Example / default |
|---|---|---|
| `PORT` | platform | `8080` |
| `BASE_PATH` | platform | `/${{ values.name }}` |
| `SERVICE_NAME`, `ENVIRONMENT` | platform | `${{ values.name }}`, `dev` / `staging` / `prod` |
| `APP_VERSION` | pipeline | `sha-<commit>`: the image running |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` | Terraform (RDS outputs) | per environment |
| `DB_PASSWORD` | **Secrets Manager**, injected by ECS at start | RDS-managed, rotatable |
| `DB_SSL` | platform | `true` on AWS, `false` locally/CI |
| `DB_SSL_CA` | image | `/app/certs/rds-global-bundle.pem` |

## Per-environment settings

Sizes, scaling and deployment style live in `infra/app/env/<environment>.tfvars`:

| Setting | dev | staging | prod |
|---|---|---|---|
| `deployment_strategy` | ROLLING | BLUE_GREEN | BLUE_GREEN |
| `bake_time_minutes` | – | 3 | 10 |
| `cpu` / `memory` | 256 / 512 | 256 / 512 | 512 / 1024 |
| `min_tasks` – `max_tasks` | 1–2 | 1–2 | 2–6 |
| `db_backup_retention_days` | 1 | 1 | 7 |
| `db_deletion_protection` | false | false | true |

Change a value → pull request → the pipeline applies it to that environment.

## Adding a new setting

1. Read it with `process.env.MY_SETTING` (with a safe default).
2. Non-secret: add it to `environment_variables` in `infra/app/main.tf`.
3. Secret: store it in Secrets Manager, add it to `secrets` and `secret_arns` in `infra/app/main.tf`
   (the task's execution role can read only the listed secrets).
