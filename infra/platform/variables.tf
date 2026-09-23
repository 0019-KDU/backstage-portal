# ---------------------------------------------------------------------------
# variables.tf — the knobs of this stack (with safe defaults)
# ---------------------------------------------------------------------------
variable "region" {
  description = "AWS region for the platform"
  type        = string
  default     = "ap-south-1"
}

variable "name" {
  description = "Prefix for all resource names (IAM policy only allows devops94-idp-*)"
  type        = string
  default     = "devops94-idp"
}

variable "vpc_cidr" {
  description = "Private IP range of the platform VPC (must not overlap the default VPC 172.31.0.0/16)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs: an ALB requires subnets in at least two"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "container_port" {
  description = "Golden-path standard: every service container listens on this port"
  type        = number
  default     = 8080
}

variable "data_availability_zones" {
  description = "AZs for private data subnets. All three: RDS instance classes are not always available in every AZ (e.g. db.t4g.micro in ap-south-1c only)."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}
