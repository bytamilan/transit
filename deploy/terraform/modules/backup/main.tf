# Backup module: an S3 bucket (versioned, encrypted, lifecycle-managed)
# for pg_dump backup artifacts, plus an IAM role a Kubernetes CronJob can
# assume via IRSA to write to it — see docs/runbooks/backup-restore.md for
# the actual backup/restore procedure this bucket is for.
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

resource "aws_kms_key" "backups" {
  description             = "${var.name_prefix} Postgres backup encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_s3_bucket" "backups" {
  bucket = "${var.name_prefix}-postgres-backups"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backups.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Retain daily backups for retention_days, then let S3 expire them —
# recovery-point objective is bounded by this, document it in the runbook.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter {}
    expiration { days = var.retention_days }
    noncurrent_version_expiration { noncurrent_days = var.retention_days }
  }
}

# IRSA role: a Kubernetes ServiceAccount annotated with this role's ARN
# can write backup objects without static AWS credentials in the cluster.
data "aws_iam_policy_document" "backup_write" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn, "${aws_s3_bucket.backups.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.backups.arn]
  }
}

resource "aws_iam_policy" "backup_write" {
  name   = "${var.name_prefix}-postgres-backup-write"
  policy = data.aws_iam_policy_document.backup_write.json
}

data "aws_iam_policy_document" "backup_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^.*oidc-provider//", "")}:sub"
      values   = ["system:serviceaccount:${var.backup_namespace}:${var.backup_service_account}"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name_prefix}-postgres-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = aws_iam_policy.backup_write.arn
}
