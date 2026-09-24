# staging: like prod (blue/green), smaller. Every change is proven here first.
environment         = "staging"
deployment_strategy = "BLUE_GREEN"
bake_time_minutes   = 3
cpu                 = 256
memory              = 512
min_tasks           = 1
max_tasks           = 2
db_instance_class   = "db.t4g.micro"

# No database code in this golden path (see the NestJS template for PostgreSQL)
use_database = false
