output "bucket_name" {
  value = aws_s3_bucket.backups.bucket
}

output "backup_role_arn" {
  value       = aws_iam_role.backup.arn
  description = "Annotate the backup CronJob's ServiceAccount with eks.amazonaws.com/role-arn = this value."
}
