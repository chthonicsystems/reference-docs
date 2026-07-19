---
library: inventory
version: 0.1.0
last-verified: 2026-07-20
tags: [extension-points, hooks, di]
summary: The extension surfaces shipped in v0.1.0 — IDbContextProvider (consumer-required) + IStockMovementSink (0..n post-commit observer) + IStockAlertPolicy (replaceable low-stock threshold). IStockLocationProvider deferred with multi-warehouse.
---

# Extension points

`@chthonic/inventory` v0.1.0 ships **three** extension surfaces. The first is consumer-required; the second is multi-subscriber; the third has an overrideable default registered by `AddChthonicInventory`.

`IStockLocationProvider` is **deferred** — multi-warehouse is explicitly out of scope for v0.1.0 (RFC 0030 § 3 + § 12 Amendment 1 12g), so a location hook now would be speculative surface.

## `IDbContextProvider` — consumer-required

```csharp
public interface IDbContextProvider
{
    DbContext GetContext();
}
```

Library services resolve the consumer's `DbContext` at runtime; the lib never compile-time depends on any product's specific context type.

**Required**: every consumer registers an impl. TorqueTech's:

```csharp
public sealed class TTInventoryDbContextProvider : IDbContextProvider
{
    private readonly TorqueTechDbContext _db;
    public TTInventoryDbContextProvider(TorqueTechDbContext db) => _db = db;
    public DbContext GetContext() => _db;
}
```

Same pattern as `@chthonic/scheduling`, `@chthonic/work`, `@chthonic/views`, etc.

## `IStockMovementSink` — post-commit observer (0..n)

```csharp
public interface IStockMovementSink
{
    Task OnMovementAsync(StockMovement movement, CancellationToken ct = default);
}
```

Fires **after** a movement is durably committed. Multi-subscriber: register any number of impls; `StockMovementBroadcaster` invokes all of them. **Sink failures are logged, never thrown** — a broken subscriber cannot fail the stock write (RFC 0030 § 12 Amendment 1 12g).

**No default is registered** — with zero sinks, `BroadcastAsync` is a no-op.

Register with the standard multi-registration pattern:

```csharp
services.AddScoped<IStockMovementSink, MyFirstSink>();
services.AddScoped<IStockMovementSink, MySecondSink>();
```

**TorqueTech impls** (two sinks):

```csharp
// 1. Accounting push — gated by the observe-only window config.
public sealed class TTStockAccountingSink : IStockMovementSink
{
    private readonly IConfiguration _config;
    private readonly IAccountingSyncPublisher _publisher;   // RabbitMQ
    private readonly ILogger<TTStockAccountingSink> _logger;

    public async Task OnMovementAsync(StockMovement m, CancellationToken ct = default)
    {
        var enabled = _config.GetValue("Inventory:AccountingPushEnabled", false);
        if (!enabled)
        {
            _logger.LogInformation(
                "[observe-only] would push variant {Variant} delta {Delta} (system {System})",
                m.ProductVariantId, m.Quantity, m.SystemId);
            return;   // Days 0–14: log, send nothing.
        }
        await _publisher.PublishStockMovementPushAsync(m, ct);   // Day 14+.
    }
}

// 2. Low-stock alert — reads the level via DbContext directly (avoids a DI cycle).
public sealed class TTLowStockAlertSink : IStockMovementSink { /* see consumption.md */ }
```

> **Why not `IStockService` inside the low-stock sink?** `StockService → StockMovementBroadcaster → sink`. If the sink took `IStockService`, that closes a construction cycle. The sink reads `InventoryLevel` off the `DbContext` directly instead.

**Future consumer:** a bay-utilization / reporting aggregator could subscribe here for incremental roll-up rather than full table scans.

## `IStockAlertPolicy` — low-stock threshold (single, replaceable)

```csharp
public interface IStockAlertPolicy
{
    bool IsLowStock(InventoryLevel level);
}
```

Decides which levels `GetLowStockAsync` returns. `GetLowStockAsync` does a broad-phase SQL filter (`ReorderPoint != null`) then a precise-phase in-memory pass through this policy — so a policy may consult fields SQL can't express.

**Default**: `DefaultStockAlertPolicy` fires when `OnHand <= ReorderPoint` (and `ReorderPoint` is set). Registered via `TryAddSingleton`, so a consumer replaces it by registering its own **before** `AddChthonicInventory` (or with an explicit `Replace`).

**Extension example** (percentage buffer):

```csharp
public sealed class PercentageBufferAlertPolicy : IStockAlertPolicy
{
    // Alert at 120% of reorder point — surface it before it actually bottoms out.
    public bool IsLowStock(InventoryLevel level) =>
        level.ReorderPoint is { } rp && level.OnHand <= (int)Math.Ceiling(rp * 1.2);
}
```

## Cross-references

- [Architecture](architecture.md)
- [Consumption](consumption.md)
- [`StockMovement` deep-ref](stock-movements.md)
- [RFC 0030 § 12 Amendment 1 12g](../../../architecture/rfcs/0030-stock-on-hand.md#12g-extension-hooks-in-v010--sink--alert-policy-per-planning-group-c-q3--b)
