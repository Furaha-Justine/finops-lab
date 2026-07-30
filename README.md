# FinCorp — Secure Supply Chain & Cross-Region DR

Two deliverables for FinCorp's platform requirements:

1. A secure, auditable CI/CD pipeline that builds immutable, vulnerability-scanned
   container images.
2. A cross-region disaster recovery setup for the primary database, with a
   demonstrated failover.

## Repository layout

```
fincorp-app/            # Node.js/Express + Postgres demo app
  Dockerfile             # multi-stage, non-root, patched base image
  src/, test/
terraform/
  bootstrap/             # Terraform state backend (S3 + DynamoDB), applied once
  main/                  # CodeArtifact, ECR, RDS, AWS Backup, IAM/OIDC
.github/workflows/
  ci-cd.yml              # the pipeline itself
docs/
  ARCHITECTURE.md         # infra design and account/region notes
  CICD-PIPELINE.md        # pipeline stages, hardening decisions, remediation
  DR-RUNBOOK.md           # backup schedule + step-by-step failover procedure
  WALKTHROUGH.md          # narrated end-to-end run with real timestamps/output
```

## Quick facts

| | |
|---|---|
| AWS Account | `976193229864` |
| Primary region | `eu-west-1` |
| DR region | `eu-central-1` |
| GitHub repo | https://github.com/Furaha-Justine/finops-lab |
| ECR repo | `fincorp-app` (immutable tags, scan-on-push) |
| RDS instance | `fincorp-primary-db` (Postgres) |
| Backup vaults | `fincorp-vault` (eu-west-1) → `fincorp-dr-vault` (eu-central-1) |

Start with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design,
or [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md) for the narrated run.
