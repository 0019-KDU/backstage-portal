# dev: fast feedback. Rolling deploys, Spot capacity, smallest sizes.
environment         = "dev"
deployment_strategy = "ROLLING"
cpu                 = 256
memory              = 512
min_tasks           = 1
max_tasks           = 2
db_instance_class   = "db.t4g.micro"

# No database code in this golden path (see the NestJS template for PostgreSQL)
use_database = false
