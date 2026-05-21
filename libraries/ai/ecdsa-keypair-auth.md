---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, auth, ecdsa, keypair]
summary: ECDSA keypair auth — tool-loop signs HTTP callbacks; consumer verifies via @chthonic/identity.
---

# ECDSA keypair auth

Tools call back into the consumer's HTTP layer (e.g. `update_profile` → `PUT /api/systems/my-system/profile`). The library signs each request with an ECDSA private key; the consumer verifies via the same `claude-ai-api-key` registered with `@chthonic/identity`.

## Setup

1. Generate ECDSA keypair (P-256).
2. Store both keys in AWS Secrets Manager:

```bash
aws secretsmanager create-secret --name torque-tech-ai-keypair-prod --secret-string '{"privateKey":"...","publicKey":"..."}'
```

3. On admin user creation, `claude-ai-api-key` is auto-registered as a `user_public_key` row with the public key + a known fingerprint.

## Sign + verify

The library's `AiKeyAuthHelper` signs request bodies with the private key (ECDSA-SHA256). Sets `X-Ai-Signature: <base64>` + `X-Ai-Fingerprint: <SHA256:...>` headers.

The consumer's `@chthonic/identity` middleware checks the headers, looks up the registered public key, verifies the signature. On failure → 401.

## Why ECDSA + keypair

Same pattern as the CLI key auth — see [`libraries/identity/api-keys.md`](../identity/api-keys.md). Reusing identity's existing infra means no new auth surface.

## Failure mode

If the keypair secret is missing or unreadable → AI generation fails at startup. The `BackgroundService` logs an actionable error: "AI__KeypairSecretName secret not found in AWS Secrets Manager."

## Related

- [`libraries/identity/api-keys.md`](../identity/api-keys.md) — sibling pattern.
- [`architecture.md`](architecture.md).
