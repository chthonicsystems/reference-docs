---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/billing`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Billing" Version="0.1.0" />
<PackageReference Include="Chthonic.Billing.Xero" Version="0.1.0" />          <!-- optional -->
<PackageReference Include="Chthonic.Billing.QuickBooks" Version="0.1.0" />    <!-- optional -->
```

## 2. Configure secrets

```bash
# Token encryption
BILLING_TOKEN_ENCRYPTION_KEY=base64-32bytes

# Xero
XERO_CLIENT_ID=...
XERO_CLIENT_SECRET=...
XERO_REDIRECT_URI=https://...

# QuickBooks
QUICKBOOKS_CLIENT_ID=...
QUICKBOOKS_CLIENT_SECRET=...
QUICKBOOKS_REDIRECT_URI=https://...
```

## 3. Register DI

```csharp
using Chthonic.Billing;
using Chthonic.Billing.Xero;
using Chthonic.Billing.QuickBooks;

builder.Services.AddChthonicBilling(builder.Configuration);
builder.Services.AddXeroAccountingProvider(builder.Configuration);
builder.Services.AddQuickBooksAccountingProvider(builder.Configuration);

app.MapBillingEndpoints();
```

## 4. Convert estimate → invoice

```csharp
public class JobCompletionService(IEstimateService estimates, IInvoiceService invoices)
{
    public async Task<Invoice> ConvertAsync(int estimateId)
    {
        var estimate = await estimates.GetAsync(estimateId);
        if (estimate.Status != EstimateStatus.Accepted)
            throw new InvalidOperationException("Only Accepted estimates convert");
        return await invoices.CreateFromEstimateAsync(estimate);
    }
}
```

## 5. OAuth connect flow

```
1. GET /api/accounting/{provider}/authorize → returns OAuth URL
2. Admin authorises in provider's UI
3. Provider redirects to /api/accounting/{provider}/callback?code=...
4. Server exchanges code → tokens; encrypts; stores in accounting_connection
5. Periodic sync starts running
```

## Related

- [`extension-points.md`](extension-points.md), [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md).
