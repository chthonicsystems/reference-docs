---
library: inventory
version: 0.1.0
last-verified: 2026-07-20
tags: [stock-movement, append-only, ledger, accounting-feed, fk-only]
summary: StockMovement deep-ref — append-only signed-quantity ledger; StockMovementType 5 values stored VARCHAR(20) via HasConversion; JobId FK-only; system+variant+occurred index; GetMovementsSinceAsync powers the accounting push feed.
---

# StockMovement

The append-only audit trail behind every stock change. One row per change; `Quantity` is **signed** (negative consumes, positive replenishes). Rows are **never updated or deleted** — a correction is a new compensating movement. The sum of a variant's movements equals its [`InventoryLevel.OnHand`](stock-on-hand.md).

## Schema

| Column | Type | Notes |
|---|---|---|
| `stock_movement_id` | INT PK | AUTO_INCREMENT |
| `system_id` | INT | Tenant scope. |
| `product_variant_id` | INT | Cross-library **FK-only** — references `Chthonic.Catalog.Domain.ProductVariant`; no nav. |
| `movement_type` | VARCHAR(20) | `StockMovementType` stored as its display string via `HasConversion` (JobStatus / JobPriority precedent). |
| `quantity` | INT | Signed delta. **Never 0** (service + endpoint reject 0 → `invalid-quantity`). |
| `job_id` | INT NULL | Cross-library **FK-only** — references `Chthonic.Work.Domain.Job`; no nav. Populated on `JobConsumption` movements by consumers with a job concept. |
| `occurred_at` | DATETIME(6) | Movement timestamp (defaults to `UtcNow` at record time). |
| `reason` | VARCHAR(500) NULL | Free-text audit note. |

**Indexes:**
- `idx_stock_movement_system_variant_occurred (system_id, product_variant_id, occurred_at)` — per-variant history (newest-first) + the level-reconstruction scan.
- `idx_stock_movement_system_occurred (system_id, occurred_at)` — the tenant-wide accounting-push feed (`GetMovementsSinceAsync`).

## StockMovementType

Five values (RFC 0030 § 4), stored as `VARCHAR(20)` display strings — additive and human-readable in the DB:

| Value | Meaning |
|---|---|
| `Sale` | Point-of-sale / counter sale decrement. |
| `Purchase` | Stock received from a supplier (positive). |
| `Adjustment` | Manual correction (stock-take, damage, shrinkage). Signed either way. |
| `Transfer` | Movement between locations (single-pool in v0.1.0; reserved for multi-warehouse). |
| `JobConsumption` | Parts fitted to a Job. The F9 auto-decrement path emits these (negative), carrying `JobId`. |

An unknown string on `POST /api/inventory/movements` → HTTP 400 `invalid-movement-type`.

## Append-only, delta-based

`StockMovement` rows are immutable. TorqueTech's line-item save path is delete-all + re-insert, so the F9 decrement wrap records the **net signed delta** per variant per save (snapshot Σ before `RemoveRange`, recompute after re-insert) as **one** `JobConsumption` movement — re-saving unchanged fields produces **no** row, and removing a fitted part records a **positive** reversal. See [consumption.md](consumption.md#delta-based-decrement-in-the-job-line-item-save-path).

## Recording a movement

```csharp
var saved = await _stock.RecordMovementAsync(new StockMovement
{
    SystemId          = systemId,
    ProductVariantId  = variantId,
    MovementType      = StockMovementType.JobConsumption,
    Quantity          = -2,          // fitted 2 units
    JobId             = jobId,
    Reason            = "Fitted to job #1225",
}, allowNegative: tenantAllowsNegative);
```

`RecordMovementAsync` inserts the row **and** applies the delta to `InventoryLevel.OnHand` in one transaction (optimistic-concurrency retry ×3), then broadcasts to every registered `IStockMovementSink` post-commit. See [architecture.md](architecture.md#recordmovementasync--signed-delta-apply-under-optimistic-concurrency).

## The accounting feed — GetMovementsSinceAsync

```csharp
Task<IReadOnlyList<StockMovement>> GetMovementsSinceAsync(int systemId, DateTime since, CancellationToken ct = default);
```

Returns every movement for a system with `OccurredAt > since`, oldest-first — the incremental cursor for accounting push. TorqueTech's `TTStockAccountingSink` pushes per-movement in real time during the Day-14+ window; `GetMovementsSinceAsync` backs reconciliation / catch-up sweeps. Movements whose variant has no `ExternalAccountingItemId` mapping are skipped + logged (never errored). See [`billing/inventory-sync.md`](../billing/inventory-sync.md).

`GetMovementsAsync(systemId, productVariantId, since?, limit)` is the per-variant, newest-first history behind the `/inventory` page (limit clamped 1–500).

## Endpoints (lib-mounted)

```
GET  /api/inventory/movements?systemId=&productVariantId=&since=&limit=  → 200 [StockMovement]
POST /api/inventory/movements                                           → 201 StockMovement
                                                                          | 400 invalid-movement-type
                                                                          | 400 invalid-quantity
                                                                          | 409 insufficient-stock
```

## Cross-references

- [`InventoryLevel` deep-ref](stock-on-hand.md)
- [Architecture — broadcaster + sinks](architecture.md#broadcaster--sinks)
- [Consumption — 14-day observe-only push window](consumption.md#14-day-observe-only-accounting-push-window)
- [`@chthonic/billing` inventory-sync — PushInventoryAdjustmentAsync](../billing/inventory-sync.md)
- [RFC 0030 § 4](../../../architecture/rfcs/0030-stock-on-hand.md)
