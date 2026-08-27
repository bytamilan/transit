variable "aws_region" {
  type        = string
  description = "e.g. \"eu-west-1\" — one region per instance of this module for a multi-region SaaS topology."
}

variable "environment" {
  type        = string
  default     = "staging"
  description = "\"staging\" or \"production\" — loosens/tightens a few defaults (NAT redundancy, public API endpoint access)."
}

variable "availability_zones" {
  type        = list(string)
  description = "At least 2 AZs in aws_region, e.g. [\"eu-west-1a\", \"eu-west-1b\"]."
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "backup_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
