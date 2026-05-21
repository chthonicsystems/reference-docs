---
library: identity
version: 0.1.4
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [identity, api-keys, cli, asymmetric-keys, ssh]
summary: Asymmetric-key auth — challenge/verify protocol for the Chthonic CLI.
---

# API keys (asymmetric-key auth)

The Chthonic CLI authenticates via SSH-style asymmetric keys. The user registers a public key in the web UI; the CLI signs a challenge with the private key; the server verifies + issues a JWT.

## Why

Username/password is bad for CLIs (rotation pain, credential storage). OAuth is bad for CLIs (browser dance every time). Asymmetric keys = SSH-equivalent ergonomics for HTTP APIs.

## Setup

### 1. Generate key pair (user side)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/chthonic_cli -N ""
ssh-keygen -e -m PKCS8 -f ~/.ssh/chthonic_cli.pub > ~/.ssh/chthonic_cli.pub.pem
```

PKCS8 PEM is what the server accepts (RSA or EC).

### 2. Register the public key

Via the web UI: navigate to API Keys, paste `chthonic_cli.pub.pem`, give it a name.

Via API:

```
POST /api/users/me/keys
Authorization: Bearer <existing token>
{
  "name": "my-laptop",
  "publicKey": "<contents of chthonic_cli.pub.pem>"
}
```

Server computes the SHA-256 fingerprint, stores `(name, public_key_pem, fingerprint, user_id)`.

### 3. CLI authenticates

```
POST /api/auth/key/challenge
{ "username": "devadmin", "fingerprint": "SHA256:..." }     # OR keyId
```

→

```
200 OK
{
  "challengeId": "<uuid>",
  "nonce": "<random base64>",       // 32 bytes
  "expiresAt": "2026-05-22T03:01:00Z"
}
```

CLI signs `nonce` with the private key (RSA-SHA256 or ECDSA-SHA256 depending on key type).

```
POST /api/auth/key/verify
{
  "challengeId": "<uuid>",
  "signature": "<base64>"
}
```

Server:
1. Looks up the challenge; verifies it hasn't expired.
2. Looks up the registered public key.
3. Verifies the signature.
4. Issues a JWT (same shape as username/password login).
5. Writes a `session_audit_log` row with `SessionAction.KeyAuthLogin`.
6. Deletes the challenge (one-time use).

## Implementation

`KeyAuthEndpoints.cs` exposes:

```
POST /api/auth/key/challenge   # creates KeyChallenge row
POST /api/auth/key/verify      # validates + consumes
```

`UserPublicKey` entity:

| Column | Notes |
|---|---|
| `key_id` | int PK |
| `user_id` | FK |
| `name` | user-provided label |
| `public_key_pem` | full PEM string |
| `fingerprint` | `SHA256:<base64>` of the SubjectPublicKeyInfo bytes |
| `created_at` | |
| `last_used_at` | nullable |

`KeyChallenge` entity:

| Column | Notes |
|---|---|
| `challenge_id` | UUID |
| `user_id` | FK |
| `nonce` | 32-byte base64 |
| `expires_at` | `created_at + 5min` |

## Both `keyId` and `fingerprint` accepted

The challenge endpoint accepts either:

```json
{ "username": "devadmin", "fingerprint": "SHA256:abc123..." }
```

OR

```json
{ "username": "devadmin", "keyId": 42 }
```

CLIs typically use fingerprint (computed locally from the private key) so they don't need to know the server-side key ID.

## RSA + ECDSA support

Both algorithms supported. Server inspects the public key's algorithm OID to pick the verification routine. RSA uses RSA-SHA256 (PKCS#1 v1.5 padding). ECDSA uses ECDSA-SHA256.

## CLI implementation

The `chthonic` CLI lives at `chthonicsystems/devops-scripts` (npm package `@chthonicsystems/devops-scripts`). It's a thin wrapper around the challenge/verify protocol.

```bash
chthonic login devadmin --domain prod --browser safari
```

Steps:
1. Reads private key from `~/.ssh/chthonic_cli`.
2. Computes fingerprint.
3. Calls `/api/auth/key/challenge`.
4. Signs the nonce.
5. Calls `/api/auth/key/verify`.
6. Receives JWT.
7. Opens the browser at `https://<host>/cli-auth.html?d=<base64>` which sets the JWT in localStorage and redirects to home.

See [`libraries/devops-scripts/`](../devops-scripts/).

## Revoking a key

```
DELETE /api/users/me/keys/{keyId}
Authorization: Bearer <token>
```

Removes the `user_public_key` row. Pending challenges remain valid for up to 5 minutes (the challenge TTL); accept this small window or invalidate matching `key_challenge` rows in the same delete.

## Audit

Every `KeyAuthLogin` writes to `session_audit_log` with the `keyId` in the metadata. The Profile page's "active sessions" view shows them.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`auth-flow.md`](auth-flow.md).
- [`libraries/devops-scripts/`](../devops-scripts/) — `chthonic` CLI consumer.
- [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md) § API keys.
