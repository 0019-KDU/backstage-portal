# ---------------------------------------------------------------------------
# ec2-instance — a small Amazon Linux 2023 server.
# Guardrails: NO SSH key and NO inbound ports; access is through AWS Systems
#   Manager Session Manager (browser shell, IAM-controlled, audited) · IMDSv2
#   required · encrypted root volume · latest Amazon Linux AMI · allowed sizes only
# ---------------------------------------------------------------------------
variable "name" {
  description = "Server name (becomes devops94-idp-res-<name>)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name))
    error_message = "name: 3-22 chars, lowercase letters, digits and '-', starts with a letter."
  }
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "instance_type must be t3.micro, t3.small or t3.medium."
  }
}
variable "root_volume_gb" {
  type    = number
  default = 20
  validation {
    condition     = var.root_volume_gb >= 8 && var.root_volume_gb <= 100
    error_message = "root_volume_gb must be between 8 and 100."
  }
}
variable "platform_name" {
  type    = string
  default = "devops94-idp"
}
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  full_name = "${var.platform_name}-res-${var.name}"
  tags      = merge(var.tags, { resource = var.name, resource-type = "ec2-instance" })
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpc" "platform" {
  tags = { Name = "${var.platform_name}-vpc" }
}
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = { tier = "public" }
}

# No ingress rules at all: nothing on the internet can connect to this server.
resource "aws_security_group" "this" {
  name        = local.full_name
  description = "EC2 ${var.name}: no inbound access, Session Manager only"
  vpc_id      = data.aws_vpc.platform.id
  tags        = merge(local.tags, { Name = local.full_name })
}

resource "aws_vpc_security_group_egress_rule" "out" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound: OS updates and Systems Manager endpoints"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.full_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = local.full_name
  role = aws_iam_role.this.name
  tags = local.tags
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true # outbound only (no NAT in the demo VPC)

  metadata_options {
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  tags        = merge(local.tags, { Name = local.full_name })
  volume_tags = local.tags

  lifecycle {
    ignore_changes = [ami] # a new AMI release must not replace a running server
  }
}

output "instance_id" { value = aws_instance.this.id }
output "private_ip" { value = aws_instance.this.private_ip }
output "session_manager_url" {
  description = "Open a browser shell (no SSH needed)"
  value       = "https://${data.aws_region.current.region}.console.aws.amazon.com/systems-manager/session-manager/${aws_instance.this.id}?region=${data.aws_region.current.region}"
}
output "console_url" {
  value = "https://${data.aws_region.current.region}.console.aws.amazon.com/ec2/home?region=${data.aws_region.current.region}#InstanceDetails:instanceId=${aws_instance.this.id}"
}
