---
library: billing
version: 0.2.0
related-rfcs: [0001, 0030]
last-verified: 2026-07-20
tags: [billing, inventory, sync, accounting-push]
summary: Two accounting-inventory flows — the unchanged pull-import (PullProductsAsync every 6h) and the new v0.2.0 push path (IAccountingProvider.PushInventoryAdjustmentAsync) that feeds @chthonic/inventory stock movements to Xero/QuickBooks.
---

# Inventory sync

`@chthonic/billing` now bridges accounting inventory in **two directions**:

1. **Pull-import** (unchanged, v0.1.x) — periodic import of the remote product list into `@chthonic/catalog`.
2. **Push** (NEW, v0.2.0) — outbound stock-quantity adjustments from `@chthonic/inventory` movements, via a new `IAccountingProvider` method.

## Pull-import (unchanged)

`PeriodicInventorySyncService : BackgroundService` runs every 6 hours. For each active `accounting_connection`:

1. Decrypt connection tokens.
2. `IAccountingProvider.PullProductsAsync(conn)` → list of remote products.
3. Diff against local `@chthonic/catalog.Product` + `ProductVariant` rows.
4. Upsert local rows:
   - New remote product → create local Product + Variant.
   - Existing match → update price / SKU / name if changed.
   - Local-only → leave alone (don't delete; consumer may have items not in accounting).
5. Write `accounting_sync_log` row with summary (created N, updated M).

The pull remains **quantity-free** — `AccountingRemoteItem` carries price/SKU/name, not stock counts. On-hand tracking is owned by [`@chthonic/inventory`](../inventory/index.md), not derived from the pull.

### Conflict resolution

Local catalog is the source of truth for `@chthonic/work` line-item references. Inventory sync NEVER deletes local products — it only adds + updates. Admins manually disable obsolete products.

### Schedule override

```csharp
builder.Services.AddChthonicBilling(opts => opts.InventorySyncInterval = TimeSpan.FromHours(2));
```

## Push path (v0.2.0 — new)

Added for F9 stock-on-hand (RFC 0030 § 12 Amendment 1 12b). The original RFC assumed `PeriodicInventorySyncService` was lib-side and could be "extended, not bumped"; live-state verification found the periodic service is **TT-side** and the existing lib sync is **pull-only**. So pushing stock adjustments is genuine implementor-facing API growth on the provider contract → **`Chthonic.Billing` v0.2.0** plus **`Chthonic.Billing.Xero` v0.2.0** and **`Chthonic.Billing.QuickBooks` v0.2.0** (both adapters implement the new method).

### New provider contract

```csharp
// Chthonic.Billing.Accounting
public record AccountingInventoryAdjustment(
    string   ExternalItemId,   // the remote accounting item id (consumer's ProductVariant.ExternalAccountingItemId)
    int      QuantityDelta,    // signed; mirrors StockMovement.Quantity
    string?  Reason,
    DateTime OccurredAt);

public interface IAccountingProvider
{
    // ... existing PullProductsAsync / invoice + customer push ...

    Task<string> PushInventoryAdjustmentAsync(
        AccountingConnection conn,
        AccountingInventoryAdjustment adjustment);   // returns the remote adjustment id
}
```

Implemented by `XeroAccountingProvider` and `QuickBooksAccountingProvider` (both v0.2.0). Phase-2 adapters (`.Myob`, `.ZohoBooks`, …) implement it when they land.

### Mapping + skip semantics

- Adjustments map to the remote item by **`ProductVariant.ExternalAccountingItemId`** — the same external id the pull-import already populates.
- A movement whose variant has **no** `ExternalAccountingItemId` is **skipped and logged, never errored** — an unmapped part must not fail the stock write or the sync sweep.
- Each successful push writes an `accounting_sync_log` row (`operation = 'push'`).

### Who calls it (TorqueTech wiring)

The push is driven by `@chthonic/inventory`'s `IStockMovementSink` hook, gated by a 14-day observe-only window:

```
StockService.RecordMovementAsync
  → StockMovementBroadcaster (post-commit)
    → TTStockAccountingSink
        · Inventory__AccountingPushEnabled=false (days 0–14): log would-be adjustment, send nothing
        · Inventory__AccountingPushEnabled=true  (day 14+):   publish RabbitMQ AccountingSyncAction.StockMovementPush
          → AccountingSyncConsumer
            → IAccountingProvider.PushInventoryAdjustmentAsync + accounting_sync_log
```

The sink + window live consumer-side ([`@chthonic/inventory` consumption](../inventory/consumption.md#14-day-observe-only-accounting-push-window)); `@chthonic/billing` owns only the provider contract + adapter impls.

## Related

- [`xero-integration.md`](xero-integration.md), [`quickbooks-integration.md`](quickbooks-integration.md).
- [`libraries/catalog/`](../catalog/) — `ProductVariant.ExternalAccountingItemId` source of the mapping.
- [`libraries/inventory/`](../inventory/index.md) — `StockMovement` push source + observe-only window.
- [RFC 0030 § 12 Amendment 1 12b](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0030-stock-on-hand.md).
