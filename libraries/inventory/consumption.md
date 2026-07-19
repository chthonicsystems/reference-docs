---
library: inventory
version: 0.1.0
last-verified: 2026-07-20
tags: [consumption, integration, torquetech]
summary: How to consume @chthonic/inventory — DI + IDbContextProvider bridge, two IStockMovementSink impls, RequireFeature('JobsInventory') route group, delta-based decrement in the job line-item save path, and the 14-day observe-only accounting-push window behind Inventory:AccountingPushEnabled. TorqueTech worked example throughout.
---

# Consumption

## Backend (.NET)

### 1. NuGet reference

```xml
<PackageReference Include="Chthonic.Inventory" Version="0.1.0" />
```

### 2. DI registration + DbContext bridge

```csharp
// Program.cs
builder.Services.AddChthonicInventory();   // IStockService + StockMovementBroadcaster + DefaultStockAlertPolicy

// Required: bridge to your DbContext.
builder.Services.AddScoped<Chthonic.Inventory.Extensions.IDbContextProvider,
    TorqueTech.Api.Features.Inventory.TTInventoryDbContextProvider>();
```

```csharp
public sealed class TTInventoryDbContextProvider : IDbContextProvider
{
    private readonly TorqueTechDbContext _db;
    public TTInventoryDbContextProvider(TorqueTechDbContext db) => _db = db;
    public DbContext GetContext() => _db;
}
```

### 3. Apply EF configurations

```csharp
// TorqueTechDbContext.OnModelCreating
modelBuilder.ApplyConfigurationsFromAssembly(
    typeof(Chthonic.Inventory.InventoryModuleMarker).Assembly);
```

### 4. Migration coexistence

`@chthonic/inventory` ships an empty-placeholder lib migration; TT owns the actual schema with the **two-migration shape** (PR 09 precedent):

- `RegisterChthonicInventory010_Initial` — `INSERT IGNORE` placeholder-history registration + idempotent `CREATE TABLE inventory_level` / `stock_movement`. Day-0 backfill reduces to seeding `OnHand=0, Reserved=0` per ProductVariant per system (there was no pre-existing TT stock column — RFC 0030 § 12 Amendment 1 12c).
- `AddJobsInventoryFeatureKey` — seeds the `tier_feature` rows for the string key `"JobsInventory"` (Standard + Premium).

### 5. Two sinks

TT registers **two** `IStockMovementSink`s (both `0..n` multi-registration):

```csharp
builder.Services.AddScoped<IStockMovementSink, TTStockAccountingSink>();
builder.Services.AddScoped<IStockMovementSink, TTLowStockAlertSink>();
```

**`TTStockAccountingSink`** — the observe-only accounting push (see § "14-day window" below).

**`TTLowStockAlertSink`** — fires TT's notification pipeline when a movement drops a variant to/below its reorder point. It re-reads the level through the `DbContext` directly (NOT through `IStockService`) to avoid a DI cycle (`StockService → Broadcaster → sink → IStockService`):

```csharp
public sealed class TTLowStockAlertSink : IStockMovementSink
{
    private readonly TorqueTechDbContext _db;
    private readonly INotificationPublisher _notify;
    // ...
    public async Task OnMovementAsync(StockMovement m, CancellationToken ct = default)
    {
        var level = await _db.Set<InventoryLevel>()
            .AsNoTracking()
            .FirstOrDefaultAsync(l => l.SystemId == m.SystemId
                                   && l.ProductVariantId == m.ProductVariantId, ct);
        if (level is { ReorderPoint: { } rp } && level.OnHand <= rp)
            await _notify.NotifyLowStockAsync(level, ct);
    }
}
```

### 6. Tier-gated route group

The lib endpoints are tier-agnostic; TT wraps them in a `RequireFeature("JobsInventory")` route group (RFC 0030 § 12h, mirroring RFC 0029 § 12i). TT also mounts its own `/api/inventory/*` composite endpoints for the dedicated page:

```csharp
app.MapGroup("")
   .RequireAuthorization()
   .AddEndpointFilter(new RequireFeatureFilter("JobsInventory"))
   .MapChthonicInventoryEndpoints();          // /api/inventory/{levels,movements,low-stock}

app.MapTTInventoryEndpoints();                 // TT composites: adjust, sync-stock, reorder editor
```

Permissions seeded **in the same PR** (PR 08 lesson): `page:inventory`, `action:adjust-stock`, `action:set-reorder-point`, granted to admin / supervisor / director.

## Delta-based decrement in the job line-item save path

The core F9 mechanic. TT's line-item write path (`JobFieldService.UpdateJobFieldsAsync`, `api/Features/Jobs/JobFieldService.cs:560-604`) is **delete-all + re-insert**. A naive insert-triggered decrement would double-count on every re-save. Instead the decrement wrap (`api/Features/Jobs/JobEndpoints.Fields.cs:138-170` + `JobStockDecrementService`) computes a **net signed delta**:

```
1. BEFORE RemoveRange: snapshot Σ Quantity per ProductVariantId across the affected field scope.
2. Re-insert the new field values.
3. AFTER re-insert: recompute Σ Quantity per ProductVariantId.
4. For each variant with a non-zero (after − before) delta:
     RecordMovementAsync(new StockMovement {
         SystemId, ProductVariantId,
         MovementType = JobConsumption,
         Quantity     = -(after - before),   // fitting parts consumes stock
         JobId        = jobId,
     }, allowNegative: tenantAllowsNegative);
```

Properties this guarantees:
- **Re-saving unchanged line items produces no movement** (delta is 0).
- **Removing a fitted part records a positive-quantity `JobConsumption` reversal** (stock returns).
- Wiring is a TT-side explicit `IStockService.RecordMovementAsync` call — `@chthonic/inventory` takes **no dependency** on `@chthonic/work` or `@chthonic/catalog` (FK-only typing).

When the tenant's "block negative stock" Config Hub setting is on, `allowNegative: false` makes an over-consuming save fail atomically with `InsufficientStockException`, which TT maps to HTTP 409 `insufficient-stock`.

> **F13 job-templates interplay:** applying a service package (`POST /api/jobs/{id}/apply-package`) routes through this same field machinery, so package application inherits the F9 decrement + negative-stock policy wholesale. See [`catalog/service-packages.md`](../catalog/service-packages.md).

## 14-day observe-only accounting-push window

Per RFC 0030 § 12 Amendment 1 12c, F9 ships accounting push behind a config gate rather than a data dual-write (there was nothing to dual-write against — `inventory_level` is a fresh table):

```
Inventory__AccountingPushEnabled   (default: false)
```

`TTStockAccountingSink` behaviour:

- **Days 0–14 (`false`):** the sink logs a structured *would-be* adjustment — including the `ProductVariant.ExternalAccountingItemId` resolution outcome — and sends **nothing** to Xero/QuickBooks.
- **Day 14+ (`true`, flipped after beta verification):** the sink publishes a RabbitMQ `AccountingSyncAction.StockMovementPush`; `AccountingSyncConsumer` calls `IAccountingProvider.PushInventoryAdjustmentAsync` and writes an `accounting_sync_log` row.

Movements for variants with no `ExternalAccountingItemId` mapping are **skipped + logged, never errored**. Full push contract in [`billing/inventory-sync.md`](../billing/inventory-sync.md).

## Frontend (TypeScript / React)

### 1. npm install + adapter wire-up

```bash
npm install @chthonicsystems/inventory@0.1.0
```

```tsx
// index.tsx
import { setInventoryHttp, setInventoryUseAuth } from '@chthonicsystems/inventory';
import { httpService } from './services/httpService';
import { useAuth } from './auth';

setInventoryHttp({
  get:  <T,>(url: string) => httpService.get(url) as Promise<T>,
  post: <T,>(url: string, body: unknown) => httpService.post(url, body) as Promise<T>,
  put:  <T,>(url: string, body: unknown) => httpService.put(url, body) as Promise<T>,
});
setInventoryUseAuth(() => ({ systemId: useAuth()?.user?.system?.systemId }));
```

### 2. Stock badge on the Products section + line-item picker

```tsx
import { StockBadge } from '@chthonicsystems/inventory';

// ProductsManager row + mechanic line-item picker (mobile parity, same PR)
<StockBadge productVariantId={variant.productVariantId} />
```

### 3. Dedicated `/inventory` page

TT's `Inventory.tsx` page (levels table, movement history, low-stock report, manual adjust, reorder-point editor) composes `useInventoryLevel` / `useStockMovements` over the TT composite + lib endpoints. Route gated by `page:inventory` + the `JobsInventory` feature.

## Cross-references

- [Architecture](architecture.md)
- [Extension points](extension-points.md)
- [`InventoryLevel` deep-ref](stock-on-hand.md)
- [`StockMovement` deep-ref](stock-movements.md)
- [`@chthonic/billing` inventory-sync — push path](../billing/inventory-sync.md)
- [`@chthonic/catalog` service-packages — F13 apply interplay](../catalog/service-packages.md)
- TT integration PR: [chthonicsystems/torquetech#315](https://github.com/chthonicsystems/torquetech/pull/315)
- [RFC 0030](../../../architecture/rfcs/0030-stock-on-hand.md)
