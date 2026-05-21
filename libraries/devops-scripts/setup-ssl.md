---
library: devops-scripts
version: 0.3.0
related-rfcs: [0019]
last-verified: 2026-05-22
tags: [devops-scripts, setup-ssl]
summary: setup-ssl — Let's Encrypt certificate + nginx config + auto-renewal cron.
---

# `setup-ssl` command

Configures Let's Encrypt SSL via certbot + nginx reverse proxy.

## Steps

1. Verify DNS resolves to the host IP (else abort with helpful error).
2. Install certbot.
3. Issue certificate via HTTP-01 challenge.
4. Generate nginx config (HTTPS listener with proxy to API/web).
5. Reload nginx.
6. Add renewal cron: `0 3 * * 1 certbot renew --quiet`.

## Usage

```bash
chthonic-devops setup-ssl --domain torquetech.chthonicsystems.com --email admin@chthonicsystems.com
```

## Architecture

```
Internet (443) → nginx (SSL termination)
                  ├→ /api/* → API (5001)
                  ├→ /.well-known/* → static
                  └→ /* → web (8100)
```

## PR 28 fix-forward

Per the extraction sequence, PR 28's reusable workflow had to inline the SSL sed-substitution due to GitHub Actions limitations. Documented in `chthonicsystems/devops-workflows` PR #2.

## Related

- [`setup-server.md`](setup-server.md), [`pre-deploy-check.md`](pre-deploy-check.md).
