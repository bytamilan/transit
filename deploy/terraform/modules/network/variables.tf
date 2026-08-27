variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names, e.g. \"transit-eu-west-1\" for a regional deployment."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.20.0.0/16"
  description = "CIDR block for the VPC. /16 gives room for /20 subnets across several AZs."
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs to spread subnets across — at least 2 for RDS Multi-AZ and EKS control-plane HA."
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "true for a single shared NAT gateway (cheaper, single point of failure) — fine for a reference/staging env, not for production."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every network resource."
}
