variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "dr_region" {
  description = "DR AWS region for cross-region backup copy"
  type        = string
  default     = "eu-central-1"
}

variable "my_ip_cidr" {
  description = "CIDR of the operator's current public IP, allowed to reach RDS on 5432"
  type        = string
  default     = "102.22.146.226/32"
}

variable "codeartifact_domain" {
  description = "CodeArtifact domain name"
  type        = string
  default     = "fincorp-domain"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the app image"
  type        = string
  default     = "fincorp-app"
}

variable "db_identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "fincorp-primary-db"
}

variable "db_name" {
  description = "Default database name created on the RDS instance"
  type        = string
  default     = "fincorp"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "fincorp_admin"
}

variable "backup_vault_name" {
  description = "Primary-region AWS Backup vault name"
  type        = string
  default     = "fincorp-vault"
}

variable "dr_backup_vault_name" {
  description = "DR-region AWS Backup vault name"
  type        = string
  default     = "fincorp-dr-vault"
}

variable "backup_plan_name" {
  description = "AWS Backup plan name"
  type        = string
  default     = "fincorp-daily-cross-region"
}
