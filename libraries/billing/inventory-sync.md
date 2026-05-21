---
library: billing
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [billing, inventory, sync]
summary: PeriodicInventorySyncService — pull product list from accounting providers + diff against catalog.
---

# Inventory sync

`PeriodicInventorySyncService : BackgroundService` runs every 6 hours. For each active `accounting_connection`:

1. Decrypt connection tokens.
2. `IAccountingProvider.PullProductsAsync(conn)` → list of remote products.
3. Diff against local `@chthonic/catalog.Product` + `ProductVariant` rows.
4. Upsert local rows:
   - New remote product → create local Product + Variant.
   - Existing match → update price / SKU / name if changed.
   - Local-only → leave alone (don't delete; consumer may have items not in accounting).
5. Write `accounting_sync_log` row with summary (created N, updated M).

## Conflict resolution

Local catalog is the source of truth for `@chthonic/work` line-item references. Inventory sync NEVER deletes local products — it only adds + updates. Admins manually disable obsolete products.

## Schedule override

```csharp
builder.Services.AddChthonicBilling(opts => opts.InventorySyncInterval = TimeSpan.FromHours(2));
```

## Related

- [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md).
- [`libraries/catalog/`](../catalog/).
