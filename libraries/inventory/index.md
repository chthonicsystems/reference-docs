---
library: inventory
package-nuget: Chthonic.Inventory
package-npm: '@chthonicsystems/inventory'
version: 0.1.0
related-rfcs: [0030]
related-libs: [catalog, billing, tenant, audit, work]
last-verified: 2026-07-20
tags: [inventory, stock, stock-movement, reorder, accounting]
summary: Stock-on-hand tracking — InventoryLevel + StockMovement append-only ledger + IStockService + 2 extension hooks. Answers "how much do we have" alongside `@chthonic/catalog`'s "what do we sell".
---

# `@chthonicsystems/inventory` / `Chthonic.Inventory`

The platform's 27th library — vertical-agnostic stock-on-hand tracking. Sits alongside [`@chthonic/catalog`](../catalog/index.md) (which owns *what a tenant sells*) to track *how much they have*. TorqueTech consumes it for workshop parts stock + auto-decrement when parts are fitted to a Job; sister-products (MarineDeck chandlery, FlowLift parts) can adopt the same surface.

Per [RFC 0030](../../../architecture/rfcs/0030-stock-on-hand.md) (with [§ 12 Amendment 1](../../../architecture/rfcs/0030-stock-on-hand.md#12-amendment-1--implementation-decisions-and-divergences-2026-07-18)).

## Purpose

- `InventoryLevel` entity — current on-hand per ProductVariant per system (one row per `(SystemId, ProductVariantId)`). FK-only typing on `ProductVariantId`.
- `StockMovement` entity — append-only signed-quantity ledger; the audit trail behind every level change. FK-only typing on `JobId`.
- `IStockService` — query levels, record movements (level delta applied atomically), per-variant history, accounting-feed query, low-stock report, reorder-point editing.
- Two extension hooks: `IStockMovementSink` (post-commit multi-subscriber observer) + `IStockAlertPolicy` (low-stock threshold override).
- Optimistic-concurrency (`RowVersion`, retry ×3) on level mutations — **no MySQL triggers** (no `log_bin_trust_function_creators` prerequisite).
- Negative on-hand is allowed by default; consumers pass `allowNegative: false` per movement to hard-block (→ `InsufficientStockException`).
- `<StockBadge>` React component + `useInventoryLevel` / `useStockMovements` hooks for consumer UIs.

## Public surface

### .NET

| Type | Role |
|---|---|
| `Domain.InventoryLevel` | Current stock level. PK `InventoryLevelId`. FK-only `ProductVariantId`. `OnHand`, `Reserved` (always 0 in v0.1.0), `ReorderPoint?`, `RowVersion` concurrency token. |
| `Domain.StockMovement` | Append-only ledger row. PK `StockMovementId`. Signed `Quantity`. FK-only `JobId?`. `MovementType`, `OccurredAt`, `Reason?`. |
| `Domain.StockMovementType` | Enum: `Sale \| Purchase \| Adjustment \| Transfer \| JobConsumption`. Stored as `VARCHAR(20)` via `HasConversion`. |
| `Services.IStockService` | Primary surface; methods: `GetLevelAsync`, `GetLevelsAsync`, `RecordMovementAsync`, `GetMovementsSinceAsync`, `GetMovementsAsync`, `GetLowStockAsync`, `SetReorderPointAsync`. |
| `Services.InsufficientStockException` | Thrown by `RecordMovementAsync(allowNegative:false)` when the result would go negative; consumer maps to HTTP 409 `insufficient-stock`. |
| `Services.StockMovementBroadcaster` | Fans a committed movement out to all registered `IStockMovementSink`s; sink failures are logged, never thrown. |
| `Extensions.IDbContextProvider` | Consumer-required: bridge to the consumer's `DbContext`. |
| `Extensions.IStockMovementSink` | Multi-subscriber post-commit observer hook. |
| `Extensions.IStockAlertPolicy` | Low-stock threshold override (default: `OnHand <= ReorderPoint`). |
| `ServiceCollectionExtensions.AddChthonicInventory` | DI registration entry point. |
| `ServiceCollectionExtensions.MapChthonicInventoryEndpoints` | Mounts endpoints under `/api/inventory/{levels,movements,low-stock}`. |
| `InventoryModuleMarker` | Assembly marker for `ApplyConfigurationsFromAssembly`. |

### npm

| Symbol | Role |
|---|---|
| `setInventoryHttp(adapter)` | Peer injection: register the `InventoryHttpAdapter` at app startup. |
| `setInventoryUseAuth(hook)` | Peer injection: register the `useAuth` hook (supplies `systemId`). |
| `useInventoryLevel(productVariantId)` | React hook; fetches one variant's `InventoryLevel`. |
| `useStockMovements(productVariantId, opts?)` | React hook; per-variant movement history. |
| `<StockBadge>` | Traffic-light on-hand badge (`green \| amber \| red`) per variant. |
| `stockBadgeLevel(level)` | Pure helper mapping an `InventoryLevel` to a badge colour. |
| Types | `InventoryLevel`, `StockMovement`, `StockMovementType`, `RecordMovementRequest`, `StockBadgeLevel`, `InventoryHttpAdapter`. |

## Schema

v0.1.0:
- New table `inventory_level` (`inventory_level_id` PK, `system_id`, `product_variant_id`, `on_hand`, `reserved`, `reorder_point` NULL, `row_version`, `updated_at`; unique `ux_inventory_level_system_variant (system_id, product_variant_id)`).
- New table `stock_movement` (`stock_movement_id` PK, `system_id`, `product_variant_id`, `movement_type` VARCHAR(20), `quantity` signed, `job_id` NULL FK-only, `occurred_at`, `reason` VARCHAR(500); indexes `idx_stock_movement_system_variant_occurred (system_id, product_variant_id, occurred_at)` + `idx_stock_movement_system_occurred (system_id, occurred_at)`).
- **No triggers.** Concurrency is optimistic via the manual `row_version` int token (portable across MySQL + SQLite). See [RFC 0030 § 12 Amendment 1 12i](../../../architecture/rfcs/0030-stock-on-hand.md#12i-concurrency--optimistic-rowversion-no-triggers).

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/catalog` | `ProductVariantId` **FK-only typing** — no nav, no compile-time dependency. |
| `@chthonic/work` | `StockMovement.JobId` **FK-only typing** — no nav, no compile-time dependency. |
| `@chthonic/tenant` | `SystemId` tenant scoping (FK-only). |
| `@chthonic/audit` | Consumer-side audit on manual adjustments. |

The lib never `PackageReference`s `@chthonic/catalog` or `@chthonic/work`; both cross-library links are `int` columns with no navigation property, mirroring `ScheduleSlot.JobId` (RFC 0029). See [architecture.md](architecture.md).

## Extension points

| Hook | Cardinality | Default | Use |
|---|---|---|---|
| `IDbContextProvider` | required, single | none | Bridge to the consumer's `DbContext`. |
| `IStockMovementSink` | 0..n | none | Post-commit observers (TT: accounting-push sink + low-stock alert sink). |
| `IStockAlertPolicy` | single (replaceable) | `DefaultStockAlertPolicy` (`OnHand <= ReorderPoint`) | Per-product / percentage low-stock thresholds. |

Full signatures + example impls in [extension-points.md](extension-points.md).

## Consuming this library

```csharp
// Program.cs
builder.Services.AddChthonicInventory();
builder.Services.AddScoped<Chthonic.Inventory.Extensions.IDbContextProvider,
    MyInventoryDbContextProvider>();          // required
builder.Services.AddScoped<IStockMovementSink, MyAccountingPushSink>();  // optional, 0..n

// MyDbContext.OnModelCreating
modelBuilder.ApplyConfigurationsFromAssembly(
    typeof(Chthonic.Inventory.InventoryModuleMarker).Assembly);

// Mount endpoints — wrap in your own tier gate (lib stays tier-agnostic).
app.MapGroup("")
   .RequireAuthorization()
   .AddEndpointFilter(new MyRequireFeatureFilter("JobsInventory"))
   .MapChthonicInventoryEndpoints();
```

```tsx
// index.tsx
import { setInventoryHttp } from '@chthonicsystems/inventory';
setInventoryHttp({ get: httpService.get, post: httpService.post, put: httpService.put });

// anywhere
import { StockBadge } from '@chthonicsystems/inventory';
<StockBadge productVariantId={variant.id} />
```

Full TorqueTech worked example (delta-based decrement, observe-only push window) in [consumption.md](consumption.md).

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`stock-on-hand.md`](stock-on-hand.md) — `InventoryLevel` deep-ref.
- [`stock-movements.md`](stock-movements.md) — `StockMovement` append-only ledger deep-ref.
- [`@chthonic/catalog`](../catalog/index.md) — ProductVariant source (what we sell).
- [`@chthonic/billing` inventory-sync](../billing/inventory-sync.md) — accounting push path (`PushInventoryAdjustmentAsync`).
- Library repo: [chthonicsystems/inventory](https://github.com/chthonicsystems/inventory).
- [RFC 0030](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0030-stock-on-hand.md).
