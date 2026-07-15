resource "aws_backup_vault" "primary" {
  name = var.backup_vault_name

  tags = {
    Project = "fincorp"
  }
}

resource "aws_backup_vault" "dr" {
  provider = aws.dr
  name     = var.dr_backup_vault_name

  tags = {
    Project = "fincorp"
  }
}

resource "aws_backup_plan" "daily_cross_region" {
  name = var.backup_plan_name

  rule {
    rule_name         = "daily-rds-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 * * ? *)"

    lifecycle {
      delete_after = 35
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn

      lifecycle {
        delete_after = 35
      }
    }
  }

  tags = {
    Project = "fincorp"
  }
}

resource "aws_backup_selection" "rds" {
  name         = "fincorp-rds-selection"
  plan_id      = aws_backup_plan.daily_cross_region.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_db_instance.primary.arn,
  ]
}
