---
library: notifications
version: 0.2.0
related-rfcs: [0009, 0025]
last-verified: 2026-05-23
tags: [notifications, extension-points]
summary: Extension points — new channel, custom templates, custom reminder milestones, open-entry watchdogs.
---

# Extension points

| Hook | Use |
|---|---|
| `INotificationChannel` | Add a new channel (e.g. WhatsApp via Twilio Business API) |
| `Templates/{key}.liquid` | Add custom template — drop in as embedded resource |
| `IReminderRule` (v0.1.x+) | Daily 02:00 UTC scan; one rule per milestone family |
| `IOpenEntryWatchdog` (v0.2.0+) | Sub-daily background scan with per-watchdog `ScanInterval`; per-UTC-day-bucketed idempotency. See [open-entry-watchdog.md](open-entry-watchdog.md). |
| `ReminderScheduler` schedule | Override DI options to change milestone offsets |
| `INotificationLogger` | Override write semantics (e.g. additional analytics integration) |

## Adding a channel

```csharp
public class WhatsAppChannel : INotificationChannel
{
    public NotificationChannel Channel => NotificationChannel.WhatsApp;
    public Task SendAsync(NotificationRequest req) { /* Twilio Business API */ }
}

builder.Services.AddScoped<INotificationChannel, WhatsAppChannel>();
```

The publisher's channel registry picks up all `INotificationChannel` impls; route by `request.Channel`.

## Custom templates

```
api/<Project>.Api.csproj — embed templates:
  <ItemGroup>
    <EmbeddedResource Include="Templates/**/*.liquid" />
  </ItemGroup>
```

Naming: `Templates/<system>.<event>.liquid`. Reader prefers consumer-supplied templates over library-shipped ones (consumer wins).

## Custom reminder milestones

```csharp
builder.Services.AddChthonicNotifications(opts =>
{
    opts.Reminders = new[]
    {
        new ReminderMilestone("PreDueDay14", -14),
        new ReminderMilestone("PreDueDay7", -7),
        new ReminderMilestone("DueDate", 0),
        new ReminderMilestone("OverdueAfterGrace", 5),
        new ReminderMilestone("OverdueAfter30", 30),
    };
});
```

## Open-entry watchdogs (v0.2.0+)

Sub-daily sibling of `IReminderRule`. For each watchdog, the
scheduler runs `ScanAsync(nowUtc, ct)` on the configured
`ScanInterval` (typically 15 minutes) and dispatches each
returned `OpenEntryHit` via the existing `INotificationPublisher` —
with idempotency via the existing `notification_log` composite
index using a per-UTC-day-bucketed key
(`"{ReminderMilestone}-{yyyy-MM-dd}"`).

```csharp
public sealed class TTLabourClockOpen8hWatchdog : IOpenEntryWatchdog
{
    private readonly TorqueTechDbContext _db;
    public string Name => "LabourClockOpen8h";
    public TimeSpan ScanInterval => TimeSpan.FromMinutes(15);

    public async Task<IReadOnlyList<OpenEntryHit>> ScanAsync(DateTime nowUtc, CancellationToken ct)
    {
        var threshold = nowUtc.AddHours(-8);
        var rows = await _db.LabourEntries
            .Where(l => l.ClockOutAt == null && l.ClockInAt < threshold)
            .Join(_db.Jobs, l => l.JobId, j => j.JobId, (l, j) => new { l, j.JobNumber })
            .ToListAsync(ct);

        return rows.Select(r => new OpenEntryHit(
            EntityType: "LabourEntry",
            EntityId: r.l.LabourEntryId,
            UserId: r.l.UserId,
            TemplateKey: "labour.clock-open-8h",
            ReminderMilestone: "LabourClockOpen8h",
            TemplateData: new Dictionary<string, object>
            {
                ["JobNumber"] = r.JobNumber,
                ["DurationOpen"] = FormatDuration(nowUtc - r.l.ClockInAt),
            })).ToList();
    }
}

services.RegisterOpenEntryWatchdog<TTLabourClockOpen8hWatchdog>();
```

The deep-ref [open-entry-watchdog.md](open-entry-watchdog.md) covers
the idempotency contract, the cadence rationale, and the F4 + F12
consumer pattern.

## Related

- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`reminders.md`](reminders.md), [`open-entry-watchdog.md`](open-entry-watchdog.md).
