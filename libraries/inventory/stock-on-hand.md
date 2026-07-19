---
library: inventory
version: 0.1.0
last-verified: 2026-07-20
tags: [inventory-level, on-hand, reorder-point, optimistic-concurrency, negative-stock]
summary: InventoryLevel deep-ref — one row per (system, variant); OnHand materialised from the ledger; Reserved always 0 in v0.1.0; nullable ReorderPoint; RowVersion optimistic token (retry ×3, no triggers); negative-stock allowNegative + InsufficientStockException → 409.
---

# InventoryLevel

The current stock position for one `ProductVariant` in one system. Exactly one row per `(SystemId, ProductVariantId)`. `OnHand` is a materialised sum of the variant's [`StockMovement`](stock-movements.md) ledger, maintained transactionally.

## Schema

| Column | Type | Notes |
|---|---|---|
| `inventory_level_id` | INT PK | AUTO_INCREMENT |
| `system_id` | INT | Tenant scope (FK-only typing → `Chthonic.Tenant.Domain.System`). |
| `product_variant_id` | INT | Cross-library **FK-only** — references `Chthonic.Catalog.Domain.ProductVariant` at runtime; **no nav property**. |
| `on_hand` | INT | Current quantity. Materialised `Σ StockMovement.Quantity`. May be negative (see below). |
| `reserved` | INT | **Always 0 in v0.1.0.** Column is schema-stable for the deferred v0.2 reservation lifecycle (RFC 0030 § 12 Amendment 1 12d). |
| `reorder_point` | INT NULL | Low-stock threshold. NULL = no alerting for this variant. |
| `row_version` | INT | Optimistic-concurrency token. Marked `IsConcurrencyToken()`; hand-incremented by `StockService` on every mutation. Plain `int` (not a DB-generated `rowversion`) for MySQL + SQLite portability. |
| `updated_at` | DATETIME(6) | Set server-side on every mutation. |

**Indexes:**
- `ux_inventory_level_system_variant (system_id, product_variant_id)` — **unique**; enforces one-row-per-variant-per-system and serves the hot single-variant lookup.

**No triggers.** Per RFC 0030 § 12 Amendment 1 12i, F9 uses optimistic concurrency instead of DB triggers, so there is **no `log_bin_trust_function_creators` prerequisite**.

## OnHand is maintained, not recomputed

The invariant `OnHand == Σ StockMovement.Quantity` (per system + variant) is held by `RecordMovementAsync`, which is the **only** writer — it inserts the movement and applies its signed delta to `OnHand` in one `SaveChanges`. There is no independent "set level" mutation that could drift the two apart. `SetReorderPointAsync` touches `ReorderPoint` / `RowVersion` / `UpdatedAt` only, never `OnHand`.

## Optimistic concurrency

`RecordMovementAsync` (and `SetReorderPointAsync`) load the level, mutate it, `RowVersion++`, and `SaveChanges`. If a concurrent writer moved `RowVersion` first, EF throws `DbUpdateConcurrencyException`; `StockService` clears the change tracker and **retries up to 3 times** before surfacing the failure. This makes concurrent movements on the same variant safe without row locks or triggers.

## Negative on-hand

Default: **allowed** (some businesses pre-sell / back-order). Callers opt into a hard block per movement:

```csharp
await _stock.RecordMovementAsync(movement, allowNegative: false);
```

When `allowNegative` is `false` and `OnHand + Quantity < 0`, the service throws:

```csharp
public class InsufficientStockException : InvalidOperationException
{
    public int ProductVariantId { get; }
    public int OnHand { get; }
    public int RequestedDelta { get; }
}
```

Consumers map it to **HTTP 409 `insufficient-stock`**. TorqueTech drives `allowNegative` from a per-tenant "block negative stock" Config Hub setting (RFC 0030 § 12 Amendment 1 12f); the same policy governs both manual adjustments and F13 package application.

## Service surface (level-facing)

| Method | Purpose |
|---|---|
| `GetLevelAsync(systemId, productVariantId, ct)` | One level, or `null` when no row exists yet. |
| `GetLevelsAsync(systemId, productVariantIds?, ct)` | All levels for a system, optionally filtered to a variant set. |
| `GetLowStockAsync(systemId, ct)` | Levels at/below their `IStockAlertPolicy` threshold. |
| `SetReorderPointAsync(systemId, productVariantId, reorderPoint?, ct)` | Set/clear the reorder point (creates the row if absent). Negative point → `ArgumentException` → HTTP 400 `invalid-reorder-point`. |
| `RecordMovementAsync(movement, allowNegative, ct)` | The `OnHand` writer — see [`stock-movements.md`](stock-movements.md). |

## Endpoints (lib-mounted)

Mounted by `MapChthonicInventoryEndpoints`; TT wraps them under `RequireFeature("JobsInventory")`:

```
GET /api/inventory/levels?systemId=&productVariantId=   → 200 InventoryLevel | 200 [InventoryLevel] | 404
PUT /api/inventory/levels/reorder-point                 → 200 InventoryLevel | 400 invalid-reorder-point
GET /api/inventory/low-stock?systemId=                  → 200 [InventoryLevel]
```

## Cross-references

- [`StockMovement` deep-ref](stock-movements.md)
- [Architecture — the level ↔ movement invariant](architecture.md#the-level--movement-invariant)
- [Extension points — IStockAlertPolicy](extension-points.md#istockalertpolicy--low-stock-threshold-single-replaceable)
- [Consumption — delta-based decrement](consumption.md#delta-based-decrement-in-the-job-line-item-save-path)
- [RFC 0030 § 12 Amendment 1 12d/12f/12i](../../../architecture/rfcs/0030-stock-on-hand.md#12-amendment-1--implementation-decisions-and-divergences-2026-07-18)
