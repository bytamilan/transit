output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "backup_bucket_name" {
  value = module.backup.bucket_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}
