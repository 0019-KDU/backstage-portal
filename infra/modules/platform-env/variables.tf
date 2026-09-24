# ---------------------------------------------------------------------------
# platform-env: everything ONE environment (dev | staging | prod) needs.
# Applied once per environment, each with its own Terraform state.
# ---------------------------------------------------------------------------
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "One /16 per environment so they never overlap (e.g. 10.20 dev, 10.21 staging, 10.22 prod)"
  type        = string
}

variable "public_azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "private_azs" {
  description = "All three AZs: RDS instance classes are not always available in every AZ"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "github_owner" {
  type    = string
  default = "0019-KDU"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner id (OIDC immutable subject claims)"
  type        = string
  default     = "112224823"
}

variable "state_bucket" {
  type    = string
  default = "devops94-idp-tfstate-697502032879"
}
