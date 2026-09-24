variable "environment" {
  type = string
}
variable "image_tag" {
  description = "Image to run (CI passes sha-<commit>; the same tag is promoted through all environments)"
  type        = string
}
variable "deployment_strategy" {
  type    = string
  default = "ROLLING"
}
variable "bake_time_minutes" {
  type    = number
  default = 5
}
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "min_tasks" {
  type    = number
  default = 1
}
variable "max_tasks" {
  type    = number
  default = 2
}
variable "use_database" {
  description = "Create a PostgreSQL database for this service in this environment"
  type        = bool
  default     = true
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "db_backup_retention_days" {
  type    = number
  default = 1
}
variable "db_deletion_protection" {
  type    = bool
  default = false
}
