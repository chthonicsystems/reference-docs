---
library: inventory
version: 0.1.0
last-verified: 2026-07-20
tags: [architecture, diagram]
summary: How InventoryLevel × StockMovement relate; how RecordMovementAsync applies a signed delta under optimistic concurrency; how StockMovementBroadcaster fans committed movements to IStockMovementSink subscribers. No triggers.
---

# Architecture

## Entity relationships

```mermaid
erDiagram
    InventoryLevel }o..|| ProductVariant : "FK-only (cross-library)"
    StockMovement  }o..|| ProductVariant : "FK-only (cross-library)"
    StockMovement  }o..o| Job : "FK-only (cross-library)"
    System ||--o{ InventoryLevel : "tenant-scoped"
    System ||--o{ StockMovement  : "tenant-scoped"

    InventoryLevel {
        int inventory_level_id PK
        int system_id
        int product_variant_id "FK-only, no nav"
        int on_hand
        int reserved "always 0 in v0.1.0"
        int reorder_point "nullable"
        int row_version "optimistic token"
        datetime updated_at
    }

    StockMovement {
        int stock_movement_id PK
        int system_id
        int product_variant_id "FK-only, no nav"
        string movement_type "VARCHAR(20)"
        int quantity "signed; never 0"
        int job_id "FK-only, nullable, no nav"
        datetime occurred_at
        string reason "nullable"
    }
```

**Key constraints:**
- One `InventoryLevel` per `(system_id, product_variant_id)` (unique `ux_inventory_level_system_variant`).
- `product_variant_id` (both tables) and `job_id` are **FK-only typing** — `int` columns with **no navigation property**. The lib never compile-time depends on `@chthonic/catalog` or `@chthonic/work`. Per RFC 0030 § 12 Amendment 1 12e, mirroring `ScheduleSlot.JobId` ([RFC 0029](../../../architecture/rfcs/0029-dispatch-board.md)) and the platform [cross-library FK-only pattern](../../platform/extension-patterns.md).
- `stock_movement` is **append-only** — rows are never updated or deleted; a correction is a new compensating movement.
- `InventoryLevel.OnHand` is a **materialised sum** of the variant's movements, maintained transactionally by `RecordMovementAsync` (not recomputed on read).

## The level ↔ movement invariant

`OnHand` and the `stock_movement` ledger are two views of the same truth:

```
InventoryLevel.OnHand  ==  Σ StockMovement.Quantity  (for that system + variant)
```

`RecordMovementAsync` is the only writer that maintains it — it inserts the movement row **and** applies the signed delta to the level row in **one `SaveChanges` unit of work**. There is no separate "adjust level" path that could drift.

## RecordMovementAsync — signed-delta apply under optimistic concurrency

```mermaid
sequenceDiagram
    participant Caller as Consumer (TT job-save)
    participant Svc as StockService
    participant DB as DbContext (consumer)
    participant BC as StockMovementBroadcaster
    participant Sink as IStockMovementSink(s)

    Caller->>Svc: RecordMovementAsync(movement, allowNegative)
    loop up to 3 attempts
        Svc->>DB: load InventoryLevel (system, variant)
        alt no level row
            Svc->>Svc: synthesise OnHand=0, Reserved=0
        end
        Svc->>Svc: newOnHand = OnHand + movement.Quantity
        alt newOnHand < 0 AND !allowNegative
            Svc-->>Caller: throw InsufficientStockException
        end
        Svc->>Svc: OnHand = newOnHand; RowVersion++; UpdatedAt = now
        Svc->>DB: Add(movement); SaveChanges (level delta + movement row)
        alt DbUpdateConcurrencyException
            Svc->>DB: ChangeTracker.Clear()
            Note over Svc: retry (RowVersion moved under us)
        else success
            Note over Svc: break
        end
    end
    Svc->>BC: BroadcastAsync(movement)   %% post-commit
    par each registered sink
        BC->>Sink: OnMovementAsync(movement)
        Note over Sink: failure logged, never rethrown
    end
    Svc-->>Caller: saved StockMovement
```

**Why optimistic, not a trigger?** RFC 0030 § 12 Amendment 1 12i: F9 deliberately avoids MySQL triggers so it carries **no `log_bin_trust_function_creators` prerequisite** (the operational trap that bit the PR 08 dispatch-board triggers on prod). `RowVersion` is a plain `int` token marked `IsConcurrencyToken()` and hand-incremented — portable across MySQL and the SQLite test provider without a DB-generated `rowversion`.

## Broadcaster + sinks

```mermaid
graph LR
    Svc[StockService] -->|post-commit| BC[StockMovementBroadcaster]
    BC --> S1[IStockMovementSink #1]
    BC --> S2[IStockMovementSink #2]
    S1 -.TT.-> TTA[TTStockAccountingSink<br/>observe-only push window]
    S2 -.TT.-> TTL[TTLowStockAlertSink<br/>notification pipeline]

    AP[IStockAlertPolicy] -.consulted by.-> Svc
    AP -->|default| DAP[DefaultStockAlertPolicy<br/>OnHand ≤ ReorderPoint]

    style Svc fill:#e3f2fd,stroke:#1565c0
    style TTA fill:#fff4e6,stroke:#e65100
    style TTL fill:#fff4e6,stroke:#e65100
```

- `IStockMovementSink` is **multi-subscriber** (`0..n`). `StockMovementBroadcaster` invokes every registered sink *after* the movement is durably committed. A sink throwing is caught + logged — a broken subscriber can never fail the stock write (RFC 0030 § 12 Amendment 1 12g).
- `IStockAlertPolicy` is a **single replaceable** service (registered via `TryAddSingleton`, so a consumer can override). `GetLowStockAsync` does a broad-phase SQL filter (`reorder_point` set) then a precise-phase in-memory pass through the policy.
- TorqueTech registers **two** sinks — a `TTStockAccountingSink` (gated by the observe-only window config) and a `TTLowStockAlertSink` (fires the notification pipeline). See [consumption.md](consumption.md).

## Tenant scoping

Both entities carry `SystemId` and every `IStockService` method takes `systemId` as its first argument — there is no ambient tenant resolution inside the lib. The consumer derives `systemId` from the authenticated principal and passes it in.

## Cross-references

- [Consumption pattern (TT worked example)](consumption.md)
- [Extension points](extension-points.md)
- [`InventoryLevel` deep-ref](stock-on-hand.md)
- [`StockMovement` deep-ref](stock-movements.md)
- [RFC 0030](../../../architecture/rfcs/0030-stock-on-hand.md)
- [platform extension-patterns — cross-library FK-only typing](../../platform/extension-patterns.md)
