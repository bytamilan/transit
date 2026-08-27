variable "name_prefix" {
  type = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "From the cluster module's output — required for IRSA."
}

variable "backup_namespace" {
  type    = string
  default = "transit"
}

variable "backup_service_account" {
  type    = string
  default = "postgres-backup"
}

variable "retention_days" {
  type        = number
  default     = 30
  description = "How long backup objects live before S3 expires them — the recovery-point-objective bound; see docs/runbooks/backup-restore.md."
}

variable "tags" {
  type    = map(string)
  default = {}
}
