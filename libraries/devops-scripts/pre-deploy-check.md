---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, pre-deploy-check]
summary: pre-deploy-check — validates secrets + DNS + SSL + S3 access before deploy.
---

# `pre-deploy-check` command

Validation gate. Run before any deploy to catch misconfiguration early.

## Checks

| # | Check | Failure mode |
|---|---|---|
| 1 | DNS resolves to expected IP | Print error + exit 1 |
| 2 | SSL certificate valid + > 7 days from expiry | Warn |
| 3 | S3 buckets exist + writable | Print missing buckets |
| 4 | GitHub Environment secrets exist (per env) | List missing secrets |
| 5 | Stripe API keys valid (test on beta; live on prod) | Print error |
| 6 | Docker image registry reachable | Connectivity check |
| 7 | API `/health` endpoint returns 200 (existing deploy) | Verify rolling deploy possible |

## Usage

```bash
chthonic-devops pre-deploy-check --env prod --product torquetech
```

## Pre-deploy hook

GitHub Actions workflow calls this before the deploy job:

```yaml
- name: Pre-deploy check
  run: npx @chthonicsystems/devops-scripts pre-deploy-check --env production
```

Exit code != 0 stops the deploy.

## Related

- [`dev-start.md`](dev-start.md), [`db-backup.md`](db-backup.md).
