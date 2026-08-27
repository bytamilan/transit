# Network module: a VPC with public subnets (NAT/ALB) and private subnets
# (EKS nodes, RDS) across the given AZs — the standard shape for an EKS +
# RDS reference topology. Uses the community terraform-aws-modules/vpc
# module rather than hand-rolled resources, since re-deriving VPC/subnet/
# route-table wiring from scratch is exactly the kind of thing that module
# already gets right.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway # false for prod HA, true to cut cost in a reference/staging env
  enable_dns_hostnames = true

  # EKS-specific subnet tags — required for the AWS load balancer
  # controller and cluster autoscaler to discover subnets correctly.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}
