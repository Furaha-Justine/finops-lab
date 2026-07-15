data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC identity provider
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github_oidc_thumbprint]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubActionsOIDCTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_fincorp" {
  name               = "github-actions-fincorp-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Project = "fincorp"
  }
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
  name   = "fincorp-github-actions-ecr"
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
  name   = "fincorp-github-actions-codeartifact"
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
  name   = "fincorp-github-actions-rds"
  policy = data.aws_iam_policy_document.rds_access.json
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.github_actions_fincorp.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "codeartifact" {
  role       = aws_iam_role.github_actions_fincorp.name
  policy_arn = aws_iam_policy.codeartifact_access.arn
}

resource "aws_iam_role_policy_attachment" "rds" {
  role       = aws_iam_role.github_actions_fincorp.name
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
