# --- Required ---------------------------------------------------------------
variable "name" {
  description = "Service name (DNS-style). Used in every resource name."
  type        = string
  validation {
    # Target group names <= 32 chars: "d94x-<name>-b"
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "name: 3-22 chars, lowercase letters, digits and '-', must start with a letter."
  }
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "image" {
  description = "Full image reference, e.g. <account>.dkr.ecr.ap-south-1.amazonaws.com/devops94-idp-svc-x:sha-abc1234"
  type        = string
}

# --- Deployment -------------------------------------------------------------
variable "deployment_strategy" {
  description = "ROLLING (replace tasks gradually) or BLUE_GREEN (full new version next to the old one, then switch traffic)"
  type        = string
  default     = "ROLLING"
  validation {
    condition     = contains(["ROLLING", "BLUE_GREEN"], var.deployment_strategy)
    error_message = "deployment_strategy must be ROLLING or BLUE_GREEN."
  }
}

variable "bake_time_minutes" {
  description = "BLUE_GREEN: how long the old (blue) version stays ready for instant rollback after traffic switched"
  type        = number
  default     = 5
}

# --- Size and scaling ----------------------------------------------------
variable "cpu" {
  description = "Fargate CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MiB"
  type        = number
  default     = 512
}

variable "min_tasks" {
  description = "Autoscaling minimum (prod: >= 2, spread over two AZs)"
  type        = number
  default     = 1
}

variable "max_tasks" {
  description = "Autoscaling maximum"
  type        = number
  default     = 2
}

variable "cpu_target_percent" {
  description = "Autoscaling keeps average CPU near this value"
  type        = number
  default     = 60
}

variable "memory_target_percent" {
  type    = number
  default = 75
}

variable "use_spot" {
  description = "Run on FARGATE_SPOT (cheaper, can be interrupted). Default: spot for dev only."
  type        = bool
  default     = null
}

# --- Configuration -----------------------------------------------------------
variable "environment_variables" {
  description = "Non-secret environment variables"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret environment variables: NAME => Secrets Manager valueFrom (e.g. \"<secret-arn>:password::\")"
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "Secrets Manager ARNs the task may read at start (must cover every entry in `secrets`)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "platform_name" {
  type    = string
  default = "devops94-idp"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "tags" {
  description = "Extra tags (owner, system, ...) added to every resource"
  type        = map(string)
  default     = {}
}
