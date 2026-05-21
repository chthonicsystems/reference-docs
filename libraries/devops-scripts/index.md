---
library: devops-scripts
package-npm: '@chthonicsystems/devops-scripts'
version: 0.3.0
related-rfcs: [0019]
related-libs: []
last-verified: 2026-05-22
tags: [devops, cli]
summary: DevOps CLI — dev-start, setup-server, setup-ssl, setup-github-envs, db-backup, pre-deploy-check.
---

# `@chthonicsystems/devops-scripts`

npm-only. CLI tool consumed by every product's `dev-start.sh` + deployment pipeline. Companion repos: `chthonicsystems/devops-workflows` (reusable GitHub Actions) + `chthonicsystems/devops-template` (CDK + monitoring + nginx scaffolding).

## Purpose

Standardise DevOps operations across products:

- `dev-start` — local dev orchestration (build + test + Docker up).
- `setup-server` — provision a Digital Ocean droplet (Docker + nginx + cron).
- `setup-ssl` — Let's Encrypt + nginx SSL config.
- `setup-github-envs` — create + populate GitHub Environments + secrets.
- `db-backup` — manual MySQL backup to S3.
- `pre-deploy-check` — validates secrets + DNS + cert + S3 access before deploy.

## Public surface

### .NET

n/a — npm-only library.

### npm

| Export | Role |
|---|---|
| `@chthonicsystems/devops-scripts` (CLI) | `npx @chthonicsystems/devops-scripts <command>` |
| `dev-start` | Build + test + Docker compose |
| `setup-server` | Droplet provisioning |
| `setup-ssl` | Let's Encrypt + nginx |
| `setup-github-envs` | GitHub Environments + secrets |
| `db-backup` | MySQL → S3 |
| `pre-deploy-check` | Validation gate |

## Companion repos

| Repo | Type | Role |
|---|---|---|
| `chthonicsystems/devops-workflows` | Reusable GitHub Actions | `deploy-beta`, `deploy-prod`, `deploy-android`, `deploy-cdk`, `deploy-monitoring` |
| `chthonicsystems/devops-template` | Git template repo | CDK stacks + monitoring config + nginx orchestration glue |

## Dependencies

| Dep | Purpose |
|---|---|
| Node 20+ | Runtime |
| AWS CLI v2 | S3 + Secrets Manager |
| Docker | Local dev |
| GitHub CLI (`gh`) | Environment + secret management |

## Extension points

| Hook | Use |
|---|---|
| Subcommand registration | `chthonic-devops <new-command>` |
| Per-product config | `.chthonicrc.json` at repo root |
| Pre/post hooks | Per-command shell hooks |

## Consuming this library

```bash
npx @chthonicsystems/devops-scripts dev-start
npx @chthonicsystems/devops-scripts pre-deploy-check
npx @chthonicsystems/devops-scripts setup-server --host 167.172.75.139
```

Or via product's wrapper script:

```bash
./dev-start.sh   # delegates to chthonic-devops dev-start
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`dev-start.md`](dev-start.md), [`setup-server.md`](setup-server.md), [`setup-ssl.md`](setup-ssl.md), [`setup-github-envs.md`](setup-github-envs.md), [`db-backup.md`](db-backup.md), [`pre-deploy-check.md`](pre-deploy-check.md).
- Library repo: [chthonicsystems/devops-scripts](https://github.com/chthonicsystems/devops-scripts).
- [RFC 0019](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0019-devops-strategy.md).
