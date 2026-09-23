# --- Required ---------------------------------------------------------------
variable "name" {
  description = "Service name (DNS-style). Used in every resource name."
  type        = string
  validation {
    # AWS name limits: target group <= 32 chars ("d94-<name>-<env>"), IAM role <= 64
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "name: 3-22 chars, lowercase letters, digits and '-', must start with a letter."
  }
}

variable "environment" {
  description = "dev | staging | prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "image" {
  description = "Full image reference, e.g. <account>.dkr.ecr.ap-south-1.amazonaws.com/devops94-idp-svc-x:sha-abc123"
  type        = string
}

# --- Optional (golden-path defaults) ----------------------------------------
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

variable "desired_count" {
  description = "Number of running tasks (0 = stopped, costs nothing)"
  type        = number
  default     = 1
}

variable "use_spot" {
  description = "Run on FARGATE_SPOT (cheaper, can be interrupted). Default: spot for non-prod."
  type        = bool
  default     = null
}

variable "environment_variables" {
  description = "Extra non-secret environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "platform_name" {
  description = "Name prefix of the shared platform stack"
  type        = string
  default     = "devops94-idp"
}

variable "container_port" {
  description = "Golden-path standard port"
  type        = number
  default     = 8080
}

variable "tags" {
  description = "Extra tags (owner, system, ...) added to every resource"
  type        = map(string)
  default     = {}
}
