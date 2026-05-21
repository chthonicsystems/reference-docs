---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, architecture]
summary: Notifications internals — publisher, channels, templates, reminders, comms.
---

# Architecture

```
src/Chthonic.Notifications/
├── Domain/NotificationLog.cs, Communication.cs
├── Configuration/
├── Services/
│   ├── INotificationPublisher.cs / NotificationPublisher.cs
│   ├── INotificationChannel.cs (per-channel abstraction)
│   ├── EmailSenderService.cs (SES)
│   ├── TwilioSmsService.cs
│   ├── FcmPushService.cs
│   ├── InAppCommunicationService.cs
│   ├── EmailTemplateRenderer.cs (Fluid + locale filters)
│   └── NotificationLogger.cs
├── ReminderScheduler.cs (BackgroundService — daily 02:00 UTC)
├── Templates/                       # embedded Liquid templates
│   ├── invoice.sent.liquid
│   ├── booking.approved.liquid
│   ├── reminder.predue7.liquid
│   └── ...
├── Endpoints/
└── ServiceCollectionExtensions.cs
```

## Idempotency

`notification_log` composite index `(entity_type, entity_id, reminder_milestone)` enforces exactly-once for reminder flows. Pre-send check:

```csharp
var existing = await _db.NotificationLogs.FirstOrDefaultAsync(n =>
    n.EntityType == entityType &&
    n.EntityId == entityId &&
    n.ReminderMilestone == milestone);
if (existing != null) return;   // already sent
```

## ReminderScheduler

Runs daily at 02:00 UTC. For each open invoice + open booking, evaluates milestones:

```
PreDueDay7      — 7 days before due
DueDate         — on due date
OverdueAfterGrace — N days after due (default 3)
```

`POST /api/debug/reminders/run?today=YYYY-MM-DD` for manual trigger in tests.

## Liquid templates

Templates live as embedded resources at `Templates/{key}.liquid`. Renderer constructs:

```
context.system     = { name, date_format, number_format, currency, timezone, ... }
context.recipient  = { name, email, mobile }
context.entity     = the relevant object (Invoice / Booking / etc.)
```

Locale filters preloaded — `{{ invoice.due_date | format_date }}` works.

## Tests

`NotificationPublisherTests`, `EmailTemplateRendererTests`, `ReminderSchedulerTests`, per-channel service tests with HTTP mocks.

## Related

- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`liquid-templates.md`](liquid-templates.md), [`reminders.md`](reminders.md).
- [RFC 0009](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0009-notifications-and-messaging.md).
