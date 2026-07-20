---
library: notifications
version: 0.3.0
related-rfcs: [0009, 0033]
last-verified: 2026-07-20
tags: [notifications, reminders, scheduler, service-reminders]
summary: ReminderScheduler — daily 02:00 UTC; idempotent via composite index; AssetServiceDue milestone (v0.3.0+).
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

## Asset service-due reminders (v0.3.0+)

`AssetServiceDueReminderRule : IReminderRule` (shipped in v0.3.0) emits the `AssetServiceDue` milestone when a vehicle/asset's next service falls within a **14-day lookahead** (`Fire.DueSoon`) and again **on the service date** (`Fire.Due`) when no booking exists.

The rule **idles when no `IAssetServiceIntervalProvider` is registered**, so v0.1.x / v0.2.x consumers are unaffected. The consuming app owns system enumeration, per-system lookahead, and feature-gating via the provider — see [`extension-points.md`](extension-points.md#iassetserviceintervalprovider-v030). TorqueTech registers `TTAssetServiceIntervalProvider`.

| Milestone | Fire | Trigger |
|---|---|---|
| `AssetServiceDue` | `DueSoon` | Next service is within the 14-day lookahead |
| `AssetServiceDue` | `Due` | Service date reached and no booking exists |

Idempotency is **day-bucketed** via `NotificationRequest.MilestoneKey` — `AssetServiceDue-{soon|due}-{yyyy-MM-dd}` — reusing the existing `notification_log` composite index. This re-arms each service cycle: a fresh key is minted for the next due date, so the same asset is reminded again on its next interval.

The reminder template is **consumer-registered** under key `asset_service_due`; the library ships no embedded template body.

### v1 deferrals

- Per-tenant lookahead is a **constant 14 days** in v1 (not yet Config-Hub tunable).
- The km-based service interval is stored but **not yet used** — v1 is time-based only.
- Booking-window suppression, job-close auto-set of `LastServiceAt`, and the Config-Hub section are follow-ups.

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
