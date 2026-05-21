---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, reminders, scheduler]
summary: ReminderScheduler — daily 02:00 UTC; idempotent via composite index.
---

# Reminders

`ReminderScheduler : BackgroundService` runs daily at 02:00 UTC. Iterates open invoices + open bookings; emits reminder notifications at configured milestones.

## Default milestones

| Milestone | Offset | Trigger |
|---|---|---|
| `PreDueDay7` | -7 days | Reminder 7 days before due date |
| `DueDate` | 0 | Reminder on due date |
| `OverdueAfterGrace` | +3 days | First overdue reminder |

Override per-product via `AddChthonicNotifications(opts.Reminders = ...)`.

## Idempotency

Composite index on `notification_log(entity_type, entity_id, reminder_milestone)` ensures exactly-once. The scheduler checks before sending:

```csharp
var alreadySent = await _db.NotificationLogs.AnyAsync(n =>
    n.EntityType == "Invoice" &&
    n.EntityId == invoice.InvoiceId &&
    n.ReminderMilestone == "PreDueDay7");

if (alreadySent) continue;
```

If the scheduler crashes mid-cycle and restarts, it picks up where it left off without re-sending.

## Manual trigger (dev / tests)

```
POST /api/debug/reminders/run?today=2026-05-22
```

Forces evaluation as if "today" is the supplied date. Used by Playwright tests.

## Per-tenant disable

Tenants opt out via `system_payment_terms.reminders_enabled = false`. The scheduler skips them.

## Related

- [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`libraries/billing/estimate-invoice-flow.md`](../billing/estimate-invoice-flow.md) — invoice consumer.
