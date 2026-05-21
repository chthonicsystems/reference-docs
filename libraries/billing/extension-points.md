---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, extension-points]
summary: Add accounting provider — IAccountingProvider impl + sister NuGet package.
---

# Extension points

| Hook | Use |
|---|---|
| `IAccountingProvider` | Add new accounting provider (MYOB, Zoho Books, Sage, FreshBooks) |
| `ITokenEncryptionService` | Override encryption (default AES-256-GCM) |
| `IPeriodicInventorySyncService` schedule | Default every 6 hours; override in DI options |

## IAccountingProvider

```csharp
public interface IAccountingProvider
{
    string Name { get; }   // 'xero', 'quickbooks', 'myob', ...

    Task<AuthorizeUrl> GetAuthorizeUrlAsync(int systemId, string redirectUri);
    Task<ConnectionResult> CompleteAuthorizeAsync(int systemId, string code, string redirectUri);
    Task<List<RemoteCustomer>> ListCustomersAsync(AccountingConnection conn);
    Task<RemoteCustomer> PushCustomerAsync(AccountingConnection conn, Customer customer);
    Task<RemoteInvoice> PushInvoiceAsync(AccountingConnection conn, Invoice invoice);
    Task<RemotePayment> PushPaymentAsync(AccountingConnection conn, Invoice invoice);
    Task<List<RemoteProduct>> PullProductsAsync(AccountingConnection conn);
    Task DisconnectAsync(AccountingConnection conn);
}
```

Phase-2 packages implement the interface, ship as sister NuGet packages (e.g. `Chthonic.Billing.Myob`).

## Token encryption override

Default impl encrypts tokens with AES-256-GCM using `BILLING_TOKEN_ENCRYPTION_KEY` env var. Override:

```csharp
public class AwsKmsTokenEncryption : ITokenEncryptionService
{
    public Task<byte[]> EncryptAsync(byte[] plaintext) { /* KMS Encrypt */ }
    public Task<byte[]> DecryptAsync(byte[] ciphertext) { /* KMS Decrypt */ }
}

builder.Services.AddSingleton<ITokenEncryptionService, AwsKmsTokenEncryption>();
```

## Related

- [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md), [`token-encryption.md`](token-encryption.md).
