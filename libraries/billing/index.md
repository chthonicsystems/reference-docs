---
library: billing
package-nuget: Chthonic.Billing
package-npm: '@chthonicsystems/billing'
version: 0.1.0
related-rfcs: [0001]
related-libs: [tenant, parties, work, payments, catalog, audit]
last-verified: 2026-05-22
tags: [work-spine, invoicing, estimates, accounting]
summary: Estimates + invoices + Xero + QuickBooks + token encryption + inventory sync.
---

# `@chthonicsystems/billing` / `Chthonic.Billing`

The work spine's "money" half. Three-package shape: `Chthonic.Billing` (interface + estimates + invoices) + `Chthonic.Billing.Xero` + `Chthonic.Billing.QuickBooks`.

## Purpose

- Generate estimates from job specs.
- Convert approved estimates to invoices.
- Push invoices + customer records to accounting (Xero / QuickBooks).
- Sync inventory levels back from accounting.
- Encrypt OAuth tokens for accounting providers.

## Public surface

### .NET

**Package: `Chthonic.Billing` (interface package)**

| Type | Role |
|---|---|
| `IEstimateService` | Estimate CRUD + send + accept/reject |
| `IInvoiceService` | Invoice CRUD + mark-paid + remind |
| `IAccountingProvider` | Provider abstraction (Xero, QuickBooks, MYOB, Zoho Books, ...) |
| `ITokenEncryptionService` | OAuth token at-rest encryption |
| `IPeriodicInventorySyncService` | Background service syncing inventory back |
| `MapBillingEndpoints` | `/api/estimates/*`, `/api/invoices/*`, `/api/accounting/*` |
| `services.AddChthonicBilling()` | DI entry point |

**Packages: `Chthonic.Billing.Xero` / `Chthonic.Billing.QuickBooks` (impl packages)**

| Type | Role |
|---|---|
| `XeroAccountingProvider : IAccountingProvider` | Xero impl |
| `QuickBooksAccountingProvider : IAccountingProvider` | QB impl |

Phase-2 packages: `.Myob`, `.ZohoBooks`, `.Sage`, `.FreshBooks`.

### npm

`@chthonicsystems/billing` ships type definitions for `Estimate`, `Invoice`, `EstimateItem`, `InvoiceItem`, `AccountingConnection` plus future hooks for billing UIs. v0.1.0 is types-only; admin UI shells stay in consumer pages until shared variants land.

## Schema

```
estimate
  estimate_id         int PK
  system_id           int
  estimate_number     varchar
  customer_id         int FK
  asset_id            int FK?     (FK-only)
  job_id              int FK?
  status              enum 'Draft', 'Sent', 'Accepted', 'Rejected', 'Expired'
  total_amount        decimal(10,2)
  currency            char(3)
  due_date            date?
  created_at          datetime

estimate_item
  estimate_item_id    int PK
  estimate_id         int FK
  product_variant_id  int FK?     (catalog)
  service_item_id     int FK?     (catalog)
  description         varchar
  quantity            decimal
  unit_price          decimal(10,2)
  display_order       int

invoice
  invoice_id          int PK
  system_id           int
  invoice_number      varchar
  customer_id         int FK
  job_id              int FK?
  status              enum 'Draft', 'Sent', 'Paid', 'Void'
  payment_intent_id   int FK?     (payments)
  total_amount        decimal(10,2)
  currency            char(3)
  due_date            date
  paid_at             datetime?

invoice_item
  invoice_item_id     int PK
  invoice_id          int FK
  product_variant_id  int FK?
  service_item_id     int FK?
  description         varchar
  quantity            decimal
  unit_price          decimal(10,2)
  display_order       int

accounting_connection
  connection_id       int PK
  system_id           int
  provider            enum 'xero', 'quickbooks', ...
  encrypted_tokens    blob
  organization_id     varchar?     # provider-specific tenant id
  connected_at        datetime
  last_sync_at        datetime?

accounting_sync_log
  sync_log_id         int PK
  system_id           int
  provider            varchar
  entity_type         varchar
  entity_id           int?
  operation           enum 'push', 'pull', 'sync'
  status              enum 'success', 'failed'
  error_message       text?
  synced_at           datetime
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/parties` | Customer FK |
| `@chthonic/work` | Job FK (FK-only) |
| `@chthonic/payments` | Payment intent on invoice paid |
| `@chthonic/catalog` | ProductVariant + ServiceItem on line items |

## Extension points

| Hook | Use |
|---|---|
| `IAccountingProvider` | Add new accounting provider (MYOB, Zoho, etc.) |
| `ITokenEncryptionService` | Override encryption (default: AES-256-GCM with key from secrets manager) |
| Periodic-sync schedule via DI options | Default: every 6 hours |

## Consuming this library

```csharp
builder.Services.AddChthonicBilling(builder.Configuration);
builder.Services.AddXeroAccountingProvider(builder.Configuration);     // optional
builder.Services.AddQuickBooksAccountingProvider(builder.Configuration); // optional
app.MapBillingEndpoints();
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`estimate-invoice-flow.md`](estimate-invoice-flow.md), [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md), [`inventory-sync.md`](inventory-sync.md), [`token-encryption.md`](token-encryption.md).
- Library repos: [chthonicsystems/billing](https://github.com/chthonicsystems/billing) + [billing-xero](https://github.com/chthonicsystems/billing-xero) + [billing-quickbooks](https://github.com/chthonicsystems/billing-quickbooks).
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md).
