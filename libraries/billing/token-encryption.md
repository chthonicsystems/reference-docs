---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, encryption, oauth-tokens]
summary: ITokenEncryptionService — at-rest encryption of OAuth tokens for accounting connections.
---

# Token encryption

OAuth refresh tokens for Xero/QuickBooks must be retained for the connection lifetime (60-100 days). They unlock the tenant's accounting account; encryption at rest is mandatory.

## Default impl

AES-256-GCM with key from `BILLING_TOKEN_ENCRYPTION_KEY` env var (base64 32 bytes).

```csharp
public class TokenEncryptionService : ITokenEncryptionService
{
    private readonly byte[] _key;
    public TokenEncryptionService(IConfiguration config)
    {
        _key = Convert.FromBase64String(config["BILLING_TOKEN_ENCRYPTION_KEY"]!);
        if (_key.Length != 32) throw new InvalidOperationException("BILLING_TOKEN_ENCRYPTION_KEY must be 32 bytes (base64).");
    }

    public byte[] Encrypt(byte[] plaintext)
    {
        using var aes = new AesGcm(_key, tagSizeInBytes: 16);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[16];
        aes.Encrypt(nonce, plaintext, ciphertext, tag);
        return Concat(nonce, tag, ciphertext);
    }

    public byte[] Decrypt(byte[] encrypted) { /* reverse */ }
}
```

## Persistence

`accounting_connection.encrypted_tokens` is a `BLOB` storing `nonce(12) || tag(16) || ciphertext`. Tokens stored as a JSON struct:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "access_token_expires_at": "..."
}
```

…serialised + encrypted.

## Override for KMS

Production deployments may prefer AWS KMS / GCP KMS / Azure Key Vault for key management:

```csharp
public class AwsKmsTokenEncryption : ITokenEncryptionService { /* KMS Encrypt/Decrypt */ }
builder.Services.AddSingleton<ITokenEncryptionService, AwsKmsTokenEncryption>();
```

## Key rotation

When rotating `BILLING_TOKEN_ENCRYPTION_KEY`:

1. Decrypt all `accounting_connection.encrypted_tokens` with old key.
2. Re-encrypt with new key.
3. Update env var.
4. Restart.

A migration script ships in the library: `scripts/rotate-billing-token-key.cs`.

## Related

- [`extension-points.md`](extension-points.md) — `ITokenEncryptionService` override.
- [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md).
