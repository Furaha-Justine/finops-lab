# FinCorp — Disaster Recovery Runbook

## Objective

Restore the FinCorp primary database in a different AWS region within
**30 minutes** of a primary-region failure.

## Steady-state backup configuration

Defined in [`terraform/main/backup.tf`](../terraform/main/backup.tf):

| | |
|---|---|
| Primary vault | `fincorp-vault` (`eu-west-1`) |
| DR vault | `fincorp-dr-vault` (`eu-central-1`) |
| Schedule | daily, `cron(0 5 * * ? *)` (05:00 UTC) |
| Retention | 35 days, both vaults |
| Cross-region copy | automatic `copy_action` on every scheduled backup |
| Protected resource | `fincorp-primary-db` (RDS Postgres) |
| Backup IAM role | `fincorp-backup-role` (AWS-managed backup/restore policies only) |

The daily schedule runs unattended — confirmed during this exercise: a
recovery point dated `07:00 CEST` (`05:00 UTC`) was already present in the
DR vault before any manual action was taken, from the automatic overnight
run.

## On-demand backup (used to demonstrate/verify without waiting for 05:00 UTC)

```bash
# 1. Take a backup into the primary vault
aws backup start-backup-job \
  --backup-vault-name fincorp-vault \
  --resource-arn arn:aws:rds:eu-west-1:<account>:db:fincorp-primary-db \
  --iam-role-arn arn:aws:iam::<account>:role/fincorp-backup-role \
  --region eu-west-1

# 2. Wait for it to complete, then copy it cross-region
aws backup describe-backup-job --backup-job-id <job-id> --region eu-west-1

aws backup start-copy-job \
  --recovery-point-arn <recovery-point-arn-from-step-1> \
  --source-backup-vault-name fincorp-vault \
  --destination-backup-vault-arn arn:aws:backup:eu-central-1:<account>:backup-vault:fincorp-dr-vault \
  --iam-role-arn arn:aws:iam::<account>:role/fincorp-backup-role \
  --region eu-west-1

# 3. Wait for the copy, then confirm it's visible in the DR region
aws backup describe-copy-job --copy-job-id <copy-job-id> --region eu-west-1
aws backup list-recovery-points-by-backup-vault --backup-vault-name fincorp-dr-vault --region eu-central-1
```

`start-backup-job` does not itself trigger a cross-region copy — that only
happens automatically when the *scheduled plan* runs (because the plan rule
has a `copy_action`). For an on-demand/ad-hoc backup outside the schedule,
the copy has to be started explicitly as shown above.

## One-time DR-region prerequisites

RDS cannot restore into a region with no networking to land in. These are
provisioned once, in Terraform ([`terraform/main/dr.tf`](../terraform/main/dr.tf)),
not created ad hoc during the incident:

- `aws_db_subnet_group.dr` — `fincorp-dr-subnet-group`, built from `eu-central-1`'s
  default VPC subnets.
- `aws_security_group.dr_rds` — `fincorp-dr-rds-sg`, allowing Postgres (5432)
  only from the operator's IP, same policy as the primary region's SG.

## Failover procedure (region failure → restored DB)

1. **Identify the latest recovery point in the DR vault:**
   ```bash
   aws backup list-recovery-points-by-backup-vault \
     --backup-vault-name fincorp-dr-vault --region eu-central-1
   ```
2. **Start the restore**, pointing at the DR-region subnet group and
   security group prepared above:
   ```bash
   aws backup start-restore-job \
     --recovery-point-arn <recovery-point-arn> \
     --iam-role-arn arn:aws:iam::<account>:role/fincorp-backup-role \
     --resource-type RDS \
     --metadata '{
       "DBInstanceClass": "db.t3.micro",
       "DBInstanceIdentifier": "fincorp-dr-restored-db",
       "DBSubnetGroupName": "fincorp-dr-subnet-group",
       "VpcSecurityGroupIds": "[\"<dr-sg-id>\"]",
       "PubliclyAccessible": "true",
       "MultiAZ": "false",
       "StorageType": "gp3",
       "Engine": "postgres"
     }' \
     --region eu-central-1
   ```
3. **Poll until the restore job completes:**
   ```bash
   aws backup describe-restore-job --restore-job-id <restore-job-id> --region eu-central-1
   ```
4. **Verify the restored instance is reachable and has the expected data**
   (connect with `psql` and check application tables/rows).
5. **Re-point the application** (connection string / DNS / secrets) at the
   new `eu-central-1` endpoint.

See [WALKTHROUGH.md](WALKTHROUGH.md) for the actual timestamps, commands,
and output from a real run of this procedure, including the total
failure-to-restored-and-verified time against the 30-minute target.

## Notes / things that would change for a production system

- This demo instance is single-AZ, `deletion_protection = false`, and
  `skip_final_snapshot = true` — appropriate for a disposable lab
  environment, not for production. A production FinCorp database would
  enable deletion protection and rely on the AWS Backup recovery points
  (as demonstrated here) rather than `skip_final_snapshot`.
- The restored instance gets a **new endpoint hostname** in `eu-central-1`;
  a production cutover would use Route 53 or an application-level
  connection-string update/secret rotation to redirect traffic without a
  code deploy.
- AWS Organizations SCPs in this account restrict which regions AWS Backup
  vaults may be created in (see [ARCHITECTURE.md](ARCHITECTURE.md)) — a
  production DR region choice should be checked against org policy first.
