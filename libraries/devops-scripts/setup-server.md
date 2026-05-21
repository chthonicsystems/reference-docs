---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, setup-server]
summary: setup-server — provision a Digital Ocean droplet (Docker + nginx + cron + monitoring).
---

# `setup-server` command

Idempotent droplet provisioning.

## Steps

1. SSH into target host as `root` (key auth required).
2. Install Docker + Docker Compose plugin.
3. Install nginx.
4. Install cron + systemd timers.
5. Clone the consumer's repo to `/opt/<product>`.
6. Configure log shipping (Fluent Bit → CloudWatch).
7. Set up daily MySQL backup cron.
8. Print success summary.

## Usage

```bash
chthonic-devops setup-server --host 167.172.75.139 --user root
```

## Idempotency

Re-running is safe. Apt installs skip if already present; clone skips if `/opt/<product>/.git` exists; cron entries de-duped.

## Related

- [`setup-ssl.md`](setup-ssl.md), [`db-backup.md`](db-backup.md).
