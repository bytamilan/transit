# Cluster module: an EKS cluster + one managed node group, with the EBS
# CSI driver add-on enabled — Transit's own Postgres runs self-hosted (the
# supabase/postgres image, per docs/adr/0001-supabase-self-host-images.md),
# not a managed database service like RDS, so its persistent volume needs
# EBS-backed dynamic provisioning inside the cluster rather than a
# separate managed-DB Terraform resource. The transit Helm chart
# (deploy/helm/transit) deploys the application workloads onto this
# cluster once it exists; Postgres itself is deployed via a StatefulFul
# manifest that isn't part of this Terraform (out of scope — see this
# module's README note).
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.name_prefix}-eks"
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy              = { most_recent = true }
    vpc-cni                 = { most_recent = true }
    aws-ebs-csi-driver      = { most_recent = true } # Postgres's PVC and the exporter's GTFS.zip PVC both need this
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = var.node_capacity_type # "ON_DEMAND" or "SPOT"
    }
  }

  tags = var.tags
}
