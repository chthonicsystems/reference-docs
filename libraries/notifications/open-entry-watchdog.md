---
library: notifications
version: 0.2.0
related-rfcs: [0025, 0033]
related-libs: [tenant, work]
last-verified: 2026-05-23
tags: [notifications, watchdog, reminders, idempotency]
summary: Sub-daily background-scan primitive for forgotten-open-entry style notifications. Sibling of the daily ReminderScheduler.
---

# Open-entry watchdog primitive

The `IOpenEntryWatchdog` + `OpenEntryWatchdogScheduler` pair is a
sub-daily sibling of the existing daily [`ReminderScheduler`](reminders.md).
Both run as `BackgroundService` instances against the same
`INotificationPublisher`; both consult the same `notification_log`
composite index for idempotency. The watchdog exists for cases where
"once a day" is too coarse — a forgotten clock-out 8 hours into a
mechanic's shift wants a 15-minute scan, not the 02:00 UTC daily run.

Shipped in `@chthonic/notifications` v0.2.0 per
[RFC 0025 § 2 Decision](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md#2-decision).
Hoisted from TT-side per
[§ 10 Alternative 3](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md#alternative-3-tt-side-watchdog-only-no-chthonicnotifications-bump)
so future per-product per-entity-type watchdogs (sister-products) inherit it.

## When to use

| Use case | Cadence | Hook |
|---|---|---|
| "Mechanic forgot to clock out > 8h" | every 15 min | `IOpenEntryWatchdog` |
| "Vehicle service due in 30 days" | once daily | `IReminderRule` |
| "Invoice 7 days from due date" | once daily | `IReminderRule` |
| "Container temp out of range > 1h" (FlowLift refrigerated cargo) | every 15 min | `IOpenEntryWatchdog` |
| "Booking starts in 24h" | once daily | `IReminderRule` |

The split is roughly: **daily scheduled reminders → `IReminderRule`**;
**sub-daily open-entry monitors → `IOpenEntryWatchdog`**.

## Public surface

### `IOpenEntryWatchdog` (interface)

```csharp
namespace Chthonic.Notifications.Reminders;

public interface IOpenEntryWatchdog
{
    /// <summary>Stable name for logging + diagnostic identification.
    /// Convention: PascalCase.</summary>
    string Name { get; }

    /// <summary>How often the scheduler runs ScanAsync. Typical
    /// value 15 minutes for forgotten-clock-out style watchdogs.
    /// Don't go shorter than 1 minute — IReminderRule is the right
    /// choice for hourly+ cadences.</summary>
    TimeSpan ScanInterval { get; }

    /// <summary>One OpenEntryHit per row that needs a notification
    /// on this scan. Empty list = no qualifying open entries; the
    /// scheduler does nothing further on this tick.</summary>
    Task<IReadOnlyList<OpenEntryHit>> ScanAsync(DateTime nowUtc, CancellationToken ct);
}
```

### `OpenEntryHit` (record)

```csharp
public sealed record OpenEntryHit(
    string EntityType,         // e.g. "LabourEntry"
    int EntityId,              // FK into the entity's table
    int? UserId,               // recipient (typically the staff member who opened the entry)
    string TemplateKey,        // Liquid template key (consumer-side seeded)
    string ReminderMilestone,  // idempotency key base (the scheduler appends "-yyyy-MM-dd")
    IReadOnlyDictionary<string, object>? TemplateData = null);
```

### `OpenEntryWatchdogScheduler` (BackgroundService)

Auto-registered as a hosted service by `AddChthonicNotifications`.
Idles when zero `IOpenEntryWatchdog` implementations are registered.
Spawns one independent loop per registered watchdog so they run on
their own intervals without blocking each other.

### DI helper

```csharp
services.RegisterOpenEntryWatchdog<TTLabourClockOpen8hWatchdog>();
// equivalent to:
services.AddScoped<IOpenEntryWatchdog, TTLabourClockOpen8hWatchdog>();
```

## Idempotency contract

The scheduler enforces "at most one notification per `(entity, day)`"
via the existing `notification_log` composite index
`(entity_type, entity_id, reminder_milestone)` — same index the daily
`ReminderScheduler` already uses for invoice reminders, so no schema
delta in `@chthonic/notifications` v0.2.0.

Per-scan flow:

1. `ScanAsync(nowUtc, ct)` returns `n` hits.
2. For each hit:
   - Compute `dayBucketedKey = "{ReminderMilestone}-{yyyy-MM-dd}"` from `nowUtc.UtcDate`.
   - Query `INotificationLogger.WasMilestoneFiredAsync(EntityType, EntityId, dayBucketedKey)`.
   - If already fired → skip.
   - Else → `INotificationPublisher.PublishAsync(...)` with `TemplateKey` + `TemplateData`.
   - On success → write a marker row with `MilestoneKey = dayBucketedKey` so the next 15-min scan in the same day-bucket short-circuits.

That means: a 9-hour open entry scanned every 15 minutes for the rest
of the day produces exactly one notification on the first scan past
the 8h boundary; the next UTC day's first scan re-fires once for any
still-open entry — escalation cadence is "one nag per day".

The `WasMilestoneFiredAsync(int, string, string)` string-keyed
overload was added in v0.2.0 alongside the watchdog; v0.1.x
consumers continue to use the typed
`WasMilestoneFiredAsync(int, string, NotificationReminderMilestone)`
overload unchanged.

## Failure handling

| Failure mode | Behaviour |
|---|---|
| `ScanAsync` throws | Caught + logged at `LogError`; the next scan tick retries. Per-watchdog isolation — other watchdogs continue. |
| Per-hit `PublishAsync` throws | Caught + logged; loop continues with the remaining hits. The next day-bucket scan re-fires for the missed hit (idempotency rules out double-notification within same day if the publish actually succeeded but the marker write failed). |
| Scheduler cancellation | Cooperative shutdown via `stoppingToken`; cleanly stops all per-watchdog loops. |

The 15-min cadence acts as the natural backoff — there's no in-loop
exponential retry. Persistent failures show up as gaps in the
`notification_log` and as `LogError` entries in CloudWatch.

## Consumer pattern (TorqueTech F4)

```csharp
// api/Features/Jobs/Labour/TTLabourClockOpen8hWatchdog.cs
public sealed class TTLabourClockOpen8hWatchdog : IOpenEntryWatchdog
{
    private readonly TorqueTechDbContext _db;
    public TTLabourClockOpen8hWatchdog(TorqueTechDbContext db) { _db = db; }

    public string Name => "LabourClockOpen8h";
    public TimeSpan ScanInterval => TimeSpan.FromMinutes(15);
    public static readonly TimeSpan OpenThreshold = TimeSpan.FromHours(8);

    public async Task<IReadOnlyList<OpenEntryHit>> ScanAsync(DateTime nowUtc, CancellationToken ct)
    {
        var threshold = nowUtc - OpenThreshold;
        var rows = await _db.LabourEntries.AsNoTracking()
            .Where(l => l.ClockOutAt == null && l.ClockInAt < threshold)
            .Join(_db.Jobs, l => l.JobId, j => j.JobId, (l, j) => new
            {
                l.LabourEntryId, l.UserId, l.ClockInAt, j.JobNumber,
            })
            .ToListAsync(ct);

        return rows.Select(r => new OpenEntryHit(
            EntityType: "LabourEntry",
            EntityId: r.LabourEntryId,
            UserId: r.UserId,
            TemplateKey: "labour.clock-open-8h",
            ReminderMilestone: "LabourClockOpen8h",
            TemplateData: new Dictionary<string, object>
            {
                ["JobNumber"] = r.JobNumber,
                ["DurationOpen"] = FormatDuration(nowUtc - r.ClockInAt),
            })).ToList();
    }
}

// Program.cs
builder.Services.AddChthonicNotifications(builder.Configuration);
builder.Services.RegisterOpenEntryWatchdog<TTLabourClockOpen8hWatchdog>();
```

## Sister-product reuse

- **TorqueTech F4** (this PR): `LabourClockOpen8h` — RFC 0025 / PR 02
- **TorqueTech F12** (planned PR 13): per-asset service-interval reminders may use `IOpenEntryWatchdog` OR extend `ReminderScheduler` with an `AssetServiceDue` milestone — choice deferred to RFC 0033 acceptance round.
- **MarineDeck**: vessel antifoul-paint expiration watchdog (12-month threshold; daily cadence — better as `IReminderRule`).
- **FlowLift**: refrigerated-cargo temp-out-of-range > 1h (15-min cadence — `IOpenEntryWatchdog`).
- **PetCare OS**: animal-in-recovery > 24h post-anaesthesia (1-hour cadence — `IOpenEntryWatchdog`).

The primitive is intentionally vertical-agnostic: it knows about
`(EntityType, EntityId, UserId?, TemplateKey, ReminderMilestone)` and
nothing else. Any product with a "row-with-an-open-state-that-needs-
follow-up-when-it-stays-open-too-long" pattern can register a watchdog.

## Related

- [`reminders.md`](reminders.md) — daily sibling
- [`extension-points.md`](extension-points.md) — registration patterns
- [`@chthonic/work` `labour-clocking.md`](../work/labour-clocking.md) — F4 consumer
- [RFC 0025 — Labour clocking](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md)
- [RFC 0033 — Service-interval reminders](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0033-service-interval-reminders.md) (downstream consumer)
