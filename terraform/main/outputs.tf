output "github_actions_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC"
  value       = aws_iam_role.github_actions_fincorp.arn
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for fincorp-app"
  value       = aws_ecr_repository.fincorp_app.repository_url
}

output "rds_endpoint" {
  description = "RDS connection endpoint (host:port) for fincorp-primary-db"
  value       = aws_db_instance.primary.endpoint
}

output "rds_address" {
  description = "RDS host only (no port) for fincorp-primary-db"
  value       = aws_db_instance.primary.address
}

output "rds_db_name" {
  description = "Default database name on fincorp-primary-db"
  value       = aws_db_instance.primary.db_name
}

output "rds_username" {
  description = "Master username on fincorp-primary-db"
  value       = aws_db_instance.primary.username
}

output "rds_password" {
  description = "Master password for fincorp-primary-db (sensitive — retrieve with terraform output -raw rds_password)"
  value       = random_password.db.result
  sensitive   = true
}

output "backup_vault_arn" {
  description = "Primary-region (us-east-1) AWS Backup vault ARN"
  value       = aws_backup_vault.primary.arn
}

output "dr_backup_vault_arn" {
  description = "DR-region (us-west-2) AWS Backup vault ARN"
  value       = aws_backup_vault.dr.arn
}

output "codeartifact_domain" {
  description = "CodeArtifact domain name"
  value       = aws_codeartifact_domain.fincorp.domain
}
