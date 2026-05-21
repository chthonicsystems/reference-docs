---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, architecture]
summary: devops-scripts internals — single CLI binary; subcommand dispatch; companion repos.
---

# Architecture

```
src/
├── bin/cli.ts                    # entry point; subcommand dispatch
├── commands/
│   ├── dev-start.ts
│   ├── setup-server.ts
│   ├── setup-ssl.ts
│   ├── setup-github-envs.ts
│   ├── db-backup.ts
│   └── pre-deploy-check.ts
├── lib/
│   ├── docker.ts                 # docker-compose helpers
│   ├── ssh.ts                    # ssh + scp helpers
│   ├── aws.ts                    # AWS CLI wrappers
│   ├── github.ts                 # gh CLI wrappers
│   └── config.ts                 # .chthonicrc.json reader
└── package.json                  # bin: chthonic-devops
```

Single npm package; zero runtime deps beyond Node built-ins.

## Companion repos

```
chthonicsystems/
├── devops-scripts             ← this npm package
├── devops-workflows           ← reusable GitHub Actions (called via `uses: chthonicsystems/devops-workflows/.github/workflows/deploy-beta.yml@v0`)
└── devops-template            ← git template repo for new products' infra (CDK + monitoring + nginx)
```

## Per-product config

`.chthonicrc.json` at the consumer's repo root:

```json
{
  "product": "torquetech",
  "domain": "torquetech.chthonicsystems.com",
  "betaDomain": "torquetech-beta.chthonicsystems.com",
  "awsRegion": "ap-southeast-1",
  "s3MediaBucket": "torque-tech-media-prod",
  "stripeKeyEnv": "STRIPE_SECRET_KEY"
}
```

## Tests

Vitest unit tests for pure-logic helpers (config parsing, version comparison). Integration tests gated behind `RUN_INTEGRATION_TESTS=true` (require live AWS + GitHub + Docker).

## Related

- [`dev-start.md`](dev-start.md), [`setup-server.md`](setup-server.md).
