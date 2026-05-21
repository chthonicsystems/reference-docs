---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, github-envs]
summary: setup-github-envs — interactive provisioning of GitHub Environments (beta, production, monitoring) with secrets.
---

# `setup-github-envs` command

Interactive setup of GitHub Environments + per-env secrets.

## What it does

1. Reads `.chthonicrc.json` for product name.
2. Creates GitHub Environments: `beta`, `production`, `monitoring`.
3. For each, prompts for required secrets:
   - `DO_HOST`, `DO_USER`, `DO_SSH_KEY`
   - `DOMAIN`, `SSL_EMAIL`
   - `S3_BACKUP_BUCKET`, `AWS_MEDIA_BUCKET`
   - Stripe keys (test for beta; live for production)
4. Pushes secrets via `gh secret set --env`.

## Repo-level secrets

Repo-level (shared across envs): `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`. Prompts at end.

## Usage

```bash
chthonic-devops setup-github-envs
```

Interactive. Skip already-set secrets unless `--force`.

## Related

- [`setup-server.md`](setup-server.md).
