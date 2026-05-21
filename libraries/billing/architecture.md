---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, architecture]
summary: Billing internals — three-package shape, accounting connection, periodic sync.
---

# Architecture

```
src/Chthonic.Billing/
├── Domain/
│   ├── Estimate.cs, EstimateItem.cs
│   ├── Invoice.cs, InvoiceItem.cs
│   ├── AccountingConnection.cs, AccountingSyncLog.cs
├── Services/
│   ├── IEstimateService.cs / EstimateService.cs
│   ├── IInvoiceService.cs / InvoiceService.cs
│   ├── IAccountingProvider.cs (interface)
│   ├── IInventoryImportService.cs / InventoryImportService.cs
│   ├── ITokenEncryptionService.cs / TokenEncryptionService.cs
│   └── PeriodicInventorySyncService.cs (BackgroundService)
├── Endpoints/    # /api/estimates/*, /api/invoices/*, /api/accounting/*
├── Configuration/, Migrations/
└── ServiceCollectionExtensions.cs
```

## State machines

### Estimate

```
Draft → Sent → Accepted → (convert to Invoice) → close
              → Rejected
              → Expired
```

### Invoice

```
Draft → Sent → Paid (via @chthonic/payments PaymentSucceededEvent)
            → Void
```

`Invoice.PaymentIntentId` links to `payment_intent` row; webhook handler updates `invoice.paid_at` + `invoice.status`.

## Periodic inventory sync

`PeriodicInventorySyncService : BackgroundService` runs every 6 hours per active accounting connection:

```
for each connection:
    pull product list from provider
    diff against local catalog
    upsert ProductVariant + Product as needed
    write accounting_sync_log row
```

Failures don't block; logged + retried next cycle.

## Tests

`EstimateServiceTests`, `InvoiceServiceTests`, `XeroAccountingProviderTests`, `QuickBooksAccountingProviderTests`, `TokenEncryptionServiceTests`, `PeriodicInventorySyncServiceTests`.

## Related

- [`estimate-invoice-flow.md`](estimate-invoice-flow.md), [`token-encryption.md`](token-encryption.md).
