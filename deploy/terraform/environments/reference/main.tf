# Reference regional environment: one VPC, one EKS cluster, one backup
# bucket, per region. A multi-region SaaS topology (build brief §2) is
# this same module set, once per region, each with its own name_prefix —
# there's no cross-region resource here to share.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "transit-${var.environment}-${var.aws_region}"
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "transit"
  })
}

module "network" {
  source = "../../modules/network"

  name_prefix        = local.name_prefix
  availability_zones  = var.availability_zones
  single_nat_gateway = var.environment != "production"
  tags               = local.tags
}

module "cluster" {
  source = "../../modules/cluster"

  name_prefix                    = local.name_prefix
  vpc_id                          = module.network.vpc_id
  private_subnet_ids              = module.network.private_subnet_ids
  cluster_endpoint_public_access  = var.environment != "production"
  node_desired_size               = var.node_desired_size
  node_min_size                   = var.node_min_size
  node_max_size                   = var.node_max_size
  tags                             = local.tags
}

module "backup" {
  source = "../../modules/backup"

  name_prefix       = local.name_prefix
  oidc_provider_arn = module.cluster.oidc_provider_arn
  retention_days    = var.backup_retention_days
  tags              = local.tags
}
