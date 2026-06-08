output "cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.db.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster"
  value       = aws_rds_cluster.db.reader_endpoint
}

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.db.cluster_identifier
}

output "db_security_group_id" {
  description = "Security Group ID of the DB tier"
  value       = aws_security_group.db.id
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the Aurora cluster"
  value       = aws_kms_key.db.arn
}
