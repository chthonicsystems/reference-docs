---
library: scheduling
version: 0.1.0
last-verified: 2026-06-06
tags: [extension-points, hooks, di]
summary: The three extension hooks shipped in v0.1.0 — IResourceTypeProvider (taxonomy), IScheduleSlotEventBus (pub/sub), IDispatchBoardPolicyProvider (overlap policy). Plus the consumer-required IDbContextProvider.
---

# Extension points

`@chthonic/scheduling` v0.1.0 ships **four** extension surfaces. The first is consumer-required; the other three have overrideable defaults registered by `AddChthonicScheduling`.

## `IDbContextProvider` — consumer-required

```csharp
public interface IDbContextProvider
{
    DbContext GetContext();
}
```

The lib's services use this to resolve the consumer's DbContext at runtime. The lib itself never compile-time depends on any consumer's DbContext type.

**Required**: every consumer must register an impl. TorqueTech's `TTSchedulingDbContextProvider`:

```csharp
public class TTSchedulingDbContextProvider : IDbContextProvider
{
    private readonly TorqueTechDbContext _db;
    public TTSchedulingDbContextProvider(TorqueTechDbContext db) => _db = db;
    public DbContext GetContext() => _db;
}
```

Same pattern as `@chthonic/booking`'s `IDbContextProvider`, `@chthonic/work`'s, etc.

## `IResourceTypeProvider` — taxonomy

```csharp
public interface IResourceTypeProvider
{
    IEnumerable<string> GetAvailableTypes();
}
```

Returns the set of valid `ResourceType` strings for the current product. The Config Hub Resources Section UI populates the type dropdown from this; service-layer validation also consults it on POST `/api/scheduling/resources` to reject unknown types.

**Default**: `DefaultResourceTypeProvider` returns `["Bay", "Lift", "Ramp"]`.

**Sister-product extension example** (MarineDeck):

```csharp
public class MarineDeckResourceTypeProvider : IResourceTypeProvider
{
    public IEnumerable<string> GetAvailableTypes()
    {
        yield return "Slip";    // primary slot type
        yield return "Mooring"; // overnight only
        yield return "Pier";    // wide vessels
    }
}
```

Register in MarineDeck's `Program.cs`:

```csharp
services.AddSingleton<IResourceTypeProvider, MarineDeckResourceTypeProvider>();
```

## `IScheduleSlotEventBus` — pub/sub seam

```csharp
public interface IScheduleSlotEventBus
{
    Task PublishCreatedAsync(ScheduleSlot slot, CancellationToken ct = default);
    Task PublishReassignedAsync(int slotId, int oldResourceId, int newResourceId, CancellationToken ct = default);
    Task PublishCancelledAsync(int slotId, CancellationToken ct = default);
    Task PublishCompletedAsync(int slotId, CancellationToken ct = default);
    Task PublishReleasedAsync(int slotId, CancellationToken ct = default);
}
```

Fires on every slot lifecycle event. `DispatchBoardService` calls `PublishCreatedAsync` / `PublishReassignedAsync` etc. after a successful DB write.

**Default**: `NoOpScheduleSlotEventBus` logs to ILogger only; takes no other side effect.

**TorqueTech impl** (logger MVP — full FCM/APNS push deferred to follow-up):

```csharp
public class TTScheduleSlotEventBus : IScheduleSlotEventBus
{
    private readonly ILogger<TTScheduleSlotEventBus> _logger;
    public TTScheduleSlotEventBus(ILogger<TTScheduleSlotEventBus> logger) => _logger = logger;

    public Task PublishReassignedAsync(int slotId, int oldResourceId, int newResourceId, CancellationToken ct = default)
    {
        // TODO (follow-up): resolve assigned mechanic via JobMechanic
        // and dispatch FCM/APNS push: "Job #X reassigned to <Resource> at <StartAt>".
        _logger.LogInformation(
            "ScheduleSlot {SlotId} reassigned from {Old} to {New}",
            slotId, oldResourceId, newResourceId);
        return Task.CompletedTask;
    }
    // ... other 4 methods
}
```

**Future consumer**: F17 bay-utilization report (RFC 0038) may subscribe to `PublishCompletedAsync` for incremental aggregation rather than full table scan.

## `IDispatchBoardPolicyProvider` — overlap policy

```csharp
public interface IDispatchBoardPolicyProvider
{
    bool AllowOverlap(string resourceType, ScheduleSlot existing, ScheduleSlot incoming);
}
```

Per-resource-type overlap policy. The MySQL trigger's hard-reject is the default; this hook lets sister-products with non-standard rules (tide-driven slip overlap, multi-vet exam rooms, capacity-limited charging stations) selectively allow overlap.

**Default**: `HardRejectOverlapPolicy` returns `false` always (matches RFC 0029 § 12 Amendment 1 12d default).

**Consultation flow**: When `AssignAsync` / `ReassignAsync` is called with `force=true`, the service checks the policy provider; if it returns `true` for the given `resourceType` and existing/incoming slots, the service issues `SET @sx_bypass_overlap_check = 1` so the trigger short-circuits. Without the policy approving, `force=true` alone is insufficient — both must agree.

**Sister-product extension example** (PetCare with multi-vet exam rooms):

```csharp
public class PetCareDispatchBoardPolicyProvider : IDispatchBoardPolicyProvider
{
    public bool AllowOverlap(string resourceType, ScheduleSlot existing, ScheduleSlot incoming)
    {
        // Exam rooms accept up to 2 vets simultaneously (e.g. complex case
        // with primary + specialist).
        if (resourceType == "ExamRoom") return true;
        return false;
    }
}
```

## Cross-references

- [Architecture](architecture.md)
- [Consumption](consumption.md)
- [ScheduleSlot conflict-detection](schedule-slots.md)
- [RFC 0029 § 12 Amendment 1 12j](../../../architecture/rfcs/0029-dispatch-board.md#12j-three-extension-hooks-in-v010-per-planning-group-c-q9--b--hookd)
