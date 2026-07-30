data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Jenkins CI identity
#
# Jenkins runs locally in Docker, not on GitHub or inside AWS, so there's no
# platform-issued OIDC token to federate against (unlike GitHub Actions'
# token.actions.githubusercontent.com). The pragmatic equivalent for a
# self-hosted/local CI server is a dedicated IAM user scoped to the same
# least-privilege permissions, with its access keys stored only in Jenkins'
# encrypted credential store (never committed to the repo).
# ---------------------------------------------------------------------------

resource "aws_iam_user" "jenkins_fincorp" {
  name = "jenkins-fincorp-ci"

  tags = {
    Project = "fincorp"
  }
}

resource "aws_iam_access_key" "jenkins_fincorp" {
  user = aws_iam_user.jenkins_fincorp.name
}

# ---------------------------------------------------------------------------
# Least-privilege permissions: ECR push/pull for fincorp-app
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecr_access" {
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRRepositoryAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = [aws_ecr_repository.fincorp_app.arn]
  }
}

resource "aws_iam_policy" "ecr_access" {
  name   = "fincorp-jenkins-ecr"
  policy = data.aws_iam_policy_document.ecr_access.json
}

# ---------------------------------------------------------------------------
# Least-privilege permissions: CodeArtifact read for fincorp-internal
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "codeartifact_access" {
  statement {
    sid    = "CodeArtifactAuth"
    effect = "Allow"
    actions = [
      "codeartifact:GetAuthorizationToken",
    ]
    resources = [aws_codeartifact_domain.fincorp.arn]
  }

  statement {
    sid    = "CodeArtifactRepoAccess"
    effect = "Allow"
    actions = [
      "codeartifact:GetRepositoryEndpoint",
      "codeartifact:ReadFromRepository",
    ]
    resources = [aws_codeartifact_repository.fincorp_internal.arn]
  }

  statement {
    sid       = "STSServiceBearerToken"
    effect    = "Allow"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values   = ["codeartifact.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "codeartifact_access" {
  name   = "fincorp-jenkins-codeartifact"
  policy = data.aws_iam_policy_document.codeartifact_access.json
}

# ---------------------------------------------------------------------------
# Least-privilege permissions: read-only RDS status check
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "rds_access" {
  statement {
    sid       = "RDSDescribeOnly"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = [aws_db_instance.primary.arn]
  }
}

resource "aws_iam_policy" "rds_access" {
  name   = "fincorp-jenkins-rds"
  policy = data.aws_iam_policy_document.rds_access.json
}

resource "aws_iam_user_policy_attachment" "ecr" {
  user       = aws_iam_user.jenkins_fincorp.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_user_policy_attachment" "codeartifact" {
  user       = aws_iam_user.jenkins_fincorp.name
  policy_arn = aws_iam_policy.codeartifact_access.arn
}

resource "aws_iam_user_policy_attachment" "rds" {
  user       = aws_iam_user.jenkins_fincorp.name
  policy_arn = aws_iam_policy.rds_access.arn
}

# ---------------------------------------------------------------------------
# Service role required by AWS Backup to perform backups/copies on our behalf
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "backup_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "fincorp-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json

  tags = {
    Project = "fincorp"
  }
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
