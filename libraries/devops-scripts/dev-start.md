---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, dev-start]
summary: dev-start command — local AWS creds refresh + dotnet test + npm build + Docker compose up.
---

# `dev-start` command

The most-used command. Local development orchestration.

## Phases

1. **AWS credentials refresh** — `~/ada-creds --profile <product> --account <id>` (skipped if `aws sts get-caller-identity` already works).
2. **API tests** — `cd api && dotnet test`. Aborts on failure.
3. **Disk-space check** — `docker image prune` if disk usage > 80%.
4. **Web build** — `cd web && npm run build`. Aborts on failure.
5. **Docker compose** — `docker compose -f docker-compose.yml -f docker-compose.local.yml up --build -d`.

## Output

On success: API at `http://localhost:5001`, web at `http://localhost:8100`, MySQL on `localhost:3306`.

## Usage

```bash
./dev-start.sh                      # full run
./dev-start.sh --skip-tests          # bypass dotnet test (rare)
./dev-start.sh --no-docker           # build only; skip container restart
```

## Hook integration

Pre-hook: `.chthonic-hooks/dev-start.pre.sh`. Post-hook: `.chthonic-hooks/dev-start.post.sh`.

## Per-product config

Reads `.chthonicrc.json` for AWS profile + product name.

## Related

- [`pre-deploy-check.md`](pre-deploy-check.md).
