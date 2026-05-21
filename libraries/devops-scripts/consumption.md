---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, consumption]
summary: Code-level integration — fork devops-template; install chthonic-devops; set up env.
---

# Consuming `@chthonicsystems/devops-scripts`

The canonical path: **fork `chthonicsystems/devops-template`** which ships with everything wired.

## 1. Fork the template

```bash
gh repo create my-org/<product>-infra --template chthonicsystems/devops-template --clone
```

## 2. Configure

Edit `.chthonicrc.json` with product-specific values (domain, S3 buckets, etc.).

## 3. Or wire from scratch

```json
"@chthonicsystems/devops-scripts": "0.3.0"
```

Or use via npx without install:

```bash
npx @chthonicsystems/devops-scripts dev-start
```

## 4. dev-start.sh wrapper

Wrap the CLI in `dev-start.sh` (the consumer's existing entry point):

```bash
#!/usr/bin/env bash
set -e
exec npx @chthonicsystems/devops-scripts dev-start "$@"
```

## 5. Reusable workflow consumption

```yaml
# File: .github/workflows/deploy-beta.yml
jobs:
  deploy:
    uses: chthonicsystems/devops-workflows/.github/workflows/deploy-beta.yml@v0
    secrets: inherit
```

## Verification

- [ ] `./dev-start.sh` builds + tests + brings up Docker.
- [ ] `chthonic-devops pre-deploy-check` passes (DNS + cert + S3 + secrets).
- [ ] GitHub Actions workflows run via reusable-workflow `uses:` references.

## Related

- [`dev-start.md`](dev-start.md), [`pre-deploy-check.md`](pre-deploy-check.md).
- Template repo: [chthonicsystems/devops-template](https://github.com/chthonicsystems/devops-template).
