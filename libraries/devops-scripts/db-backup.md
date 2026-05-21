---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, backup]
summary: db-backup — manual MySQL → S3 backup. Used by daily cron + ad-hoc.
---

# `db-backup` command

Backs up MySQL to S3 with gzip + Glacier lifecycle.

## Steps

1. `mysqldump --single-transaction <db>` to local temp file.
2. `gzip -9` the dump.
3. `aws s3 cp <file>.sql.gz s3://<backup-bucket>/<product>-<date>.sql.gz`.
4. Print the S3 URL.

## Usage

```bash
chthonic-devops db-backup --product torquetech --env prod
```

Daily cron: `0 20 * * * /usr/local/bin/chthonic-devops db-backup --product torquetech --env prod`

## Lifecycle

S3 bucket has 90-day Glacier rule. After 90 days, backups transition to Glacier (cheaper but slow restore). Lifecycle managed by CDK (`devops-template`).

## Related

- [`pre-deploy-check.md`](pre-deploy-check.md), [`setup-server.md`](setup-server.md).
