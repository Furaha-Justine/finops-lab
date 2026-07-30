# FinCorp — Architecture

## Objective

FinCorp needs a secure, auditable software supply chain and a cross-region
disaster recovery (DR) plan that can restore its critical database in a
different AWS region within 30 minutes.

## AWS account and regions

| Item | Value |
|---|---|
| AWS Account | `976193229864` |
| Primary region | `eu-west-1` (Ireland) |
| DR region | `eu-central-1` (Frankfurt) |
| GitHub repo | [Furaha-Justine/finops-lab](https://github.com/Furaha-Justine/finops-lab) |

**Note on regions:** the original brief specifies `us-east-1` / `us-west-2`.
This account is governed by an AWS Organizations Service Control Policy (SCP)
that restricts which regions member accounts may use. Testing showed
`us-west-2`, `eu-west-2`, and `eu-west-3` are explicitly denied for AWS
Backup, while `eu-west-1` and `eu-central-1` are permitted — so the primary
and DR regions were moved accordingly. The pattern (single-region primary,
independent-region DR copy, org-level guardrails respected) is unchanged.

## Components

```
                      ┌─────────────────────────────┐
  git push            │        GitHub Actions       │
  (main branch) ─────▶│  build → test → scan → push │
                      └──────────────┬───────────────┘
                                     │ OIDC (no long-lived keys)
                                     ▼
        ┌───────────────────────────────────────────────────┐
        │                  AWS Account 976193229864          │
        │                                                     │
        │  eu-west-1 (primary)                               │
        │  ┌───────────────┐   ┌───────────────┐             │
        │  │  CodeArtifact │   │      ECR       │             │
        │  │  npm-store    │   │  fincorp-app   │             │
        │  │  (proxies     │   │  IMMUTABLE tags│             │
        │  │  npmjs.org)   │   │  scan-on-push  │             │
        │  └───────────────┘   └───────────────┘             │
        │                                                     │
        │  ┌───────────────┐   ┌───────────────┐             │
        │  │ RDS Postgres  │──▶│ AWS Backup     │             │
        │  │ fincorp-      │   │ vault:         │             │
        │  │ primary-db    │   │ fincorp-vault  │             │
        │  └───────────────┘   └───────┬────────┘             │
        │                              │ daily cross-region   │
        │                              │ copy_action           │
        │  eu-central-1 (DR)           ▼                       │
        │                      ┌───────────────┐               │
        │                      │ AWS Backup     │               │
        │                      │ vault:         │               │
        │                      │ fincorp-dr-    │               │
        │                      │ vault          │               │
        │                      └───────────────┘               │
        └───────────────────────────────────────────────────┘
```

## Terraform layout

```
terraform/
  bootstrap/   # S3 state bucket + DynamoDB lock table (applied once, local state)
  main/        # everything else (remote S3 backend)
    versions.tf     # providers + S3 backend config
    variables.tf    # region, naming, CIDR inputs
    iam.tf          # GitHub OIDC provider + role, least-privilege policies, AWS Backup service role
    codeartifact.tf # CodeArtifact domain + npm-store (proxy) + fincorp-internal (consumer repo)
    ecr.tf          # ECR repo: IMMUTABLE tags + scan_on_push
    rds.tf          # RDS Postgres primary + security group scoped to operator IP
    backup.tf       # primary + DR vaults, daily backup plan with cross-region copy_action
    outputs.tf
```

State lives in S3 (`fincorp-terraform-state-976193229864`, versioned,
encrypted, public access blocked) with a DynamoDB lock table
(`fincorp-terraform-lock`) — not in local files, and not committed to git
(`.tfstate`/`.tfplan`/`.terraform/` are gitignored).

## Identity and access

- **GitHub Actions → AWS**: no static access keys. The workflow assumes
  `github-actions-fincorp-role` via OIDC
  (`token.actions.githubusercontent.com`), trust-scoped to
  `repo:Furaha-Justine/finops-lab:*`. The role has three narrowly-scoped
  policies: push/pull to the one ECR repo, read from the one CodeArtifact
  repo, and `rds:DescribeDBInstances` only — no write access to the database
  or any other AWS resource.
- **AWS Backup → RDS/vaults**: a dedicated `fincorp-backup-role` service role
  with only the AWS-managed `AWSBackupServiceRolePolicyForBackup` and
  `...ForRestores` policies attached.
- **RDS network access**: the security group only allows port 5432 from the
  operator's own IP (`/32`), not `0.0.0.0/0`.

## Why CodeArtifact "proxies" npmjs

`npm-store` is a CodeArtifact repository with an `external_connection` to
`public:npmjs`, so it fetches and caches packages from the public npm
registry on first request. `fincorp-internal` has `npm-store` as its
upstream, so all installs on CI go through
`fincorp-internal → npm-store → npmjs.org`. This gives a single controlled,
auditable ingress point for third-party packages instead of every build
pulling directly from the public internet.
