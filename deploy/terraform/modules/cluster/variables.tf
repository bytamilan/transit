variable "name_prefix" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_endpoint_public_access" {
  type        = bool
  default     = false
  description = "false = only reachable from inside the VPC (bastion/VPN) — true only for a reference/demo environment where that's impractical."
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "tags" {
  type    = map(string)
  default = {}
}
