# prod: blue/green with a longer bake time (instant rollback window),
# at least 2 tasks in 2 AZs, autoscaling up to 6, on-demand capacity (no Spot),
# longer database backups and deletion protection.
environment              = "prod"
deployment_strategy      = "BLUE_GREEN"
bake_time_minutes        = 10
cpu                      = 512
memory                   = 1024
min_tasks                = 2
max_tasks                = 6
db_instance_class        = "db.t4g.micro"
db_backup_retention_days = 7
db_deletion_protection   = true
