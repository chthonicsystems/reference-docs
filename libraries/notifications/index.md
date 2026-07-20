---
library: notifications
package-nuget: Chthonic.Notifications
package-npm: '@chthonicsystems/notifications'
version: 0.3.0
related-rfcs: [0009, 0025, 0033]
related-libs: [tenant, parties, templating, audit]
last-verified: 2026-07-20
tags: [communications, multi-channel, liquid, reminders, watchdog, service-reminders]
summary: Multi-channel publisher (push/email/SMS/in-app) + Liquid templates + daily reminders + sub-daily open-entry watchdog primitive + asset service-due reminders + comms.
---

# `@chthonicsystems/notifications` / `Chthonic.Notifications`

Multi-channel notification publisher. Email (Amazon SES), SMS (Twilio), push (Firebase FCM), in-app. Single `INotificationPublisher` for all channels; Liquid templates per template-key per channel.

## Purpose

- One canonical send pipeline across all channels.
- Liquid email/SMS templates with `@chthonic/locale` filters preloaded.
- `notification_log` for idempotency + audit.
- `ReminderScheduler` for invoice / booking reminders.
- `<CommunicationsPanel>` for in-app inbox.

## Public surface

### .NET

| Type | Role |
|---|---|
| `INotificationPublisher` / `NotificationPublisher` | `PublishAsync(channel, recipient, templateKey, data)` |
| `IEmailSenderService` / `EmailSenderService` | SES wrapper |
| `ITwilioSmsService` / `TwilioSmsService` | Twilio wrapper |
| `IFcmPushService` / `FcmPushService` | Firebase FCM wrapper |
| `IEmailTemplateRenderer` / `EmailTemplateRenderer` | Fluid + locale filters; reads templates from `Templates/` embedded resources |
| `INotificationLogger` / `NotificationLogger` | Writes `notification_log` rows |
| `ReminderScheduler` | BackgroundService — daily 02:00 UTC |
| `IOpenEntryWatchdog` (v0.2.0+) | Sub-daily background-scan interface — sibling of `IReminderRule`. Per-watchdog `ScanInterval`. See [open-entry-watchdog.md](open-entry-watchdog.md). |
| `OpenEntryHit` (v0.2.0+) | Dispatch payload record `(EntityType, EntityId, UserId?, TemplateKey, ReminderMilestone, TemplateData?)` |
| `OpenEntryWatchdogScheduler` (v0.2.0+) | BackgroundService — runs each `IOpenEntryWatchdog` on its own interval; per-UTC-day-bucketed idempotency via existing `notification_log` composite index |
| `IAssetServiceIntervalProvider` (v0.3.0+) | Consumer-implemented provider feeding `AssetServiceDueReminderRule`; `GetDueAsync(now, ct) → IAsyncEnumerable<AssetServiceDueRecord>`. Owns system enumeration + lookahead + feature-gating. See [extension-points.md](extension-points.md#iassetserviceintervalprovider-v030). |
| `AssetServiceDueRecord` (v0.3.0+) | Record `(SystemId, AssetId, CustomerId, CustomerEmail, CustomerName, NextServiceAt, ServiceType, Fire)` where `Fire ∈ {DueSoon, Due}` |
| `AssetServiceDueReminderRule` (v0.3.0+) | `IReminderRule` shipping the `AssetServiceDue` milestone; idles when no `IAssetServiceIntervalProvider` is registered. Day-bucketed key `AssetServiceDue-{soon\|due}-{yyyy-MM-dd}` |
| `MapNotificationEndpoints` | `/api/notifications/*`, `/api/notification-logs/*`, `/api/communications/*` |
| `services.AddChthonicNotifications(config)` | DI entry point — auto-registers both schedulers |
| `services.RegisterOpenEntryWatchdog<T>()` (v0.2.0+) | DI helper to register a watchdog; mirror of `RegisterReminderRule<T>` |

### npm

| Export | Role |
|---|---|
| `<CommunicationsInbox>` | In-app notification inbox |
| `useCommunications()` | Hook for inbox |
| `setCommunicationsHttp` | Adapter |

## Schema

```
notification_log
  notification_log_id  bigint PK
  system_id            int
  channel              enum 'email', 'sms', 'push', 'in_app'
  recipient            varchar     # email, mobile, fcm token, user id
  template_key         varchar     # 'invoice.sent', 'booking.approved', 'reminder.predue7'
  entity_type          varchar?
  entity_id            int?
  reminder_milestone   varchar?    # 'PreDueDay7', 'DueDate', 'OverdueAfterGrace'
  status               enum 'queued', 'sent', 'failed'
  error_message        text?
  sent_at              datetime?
  created_at           datetime

  index ix_notification_log_invoice_milestone (entity_type, entity_id, reminder_milestone)   # idempotency
  index ix_notification_log_system_created (system_id, created_at)

# In-app communications
communication
  communication_id     int PK
  system_id            int
  user_id              int
  channel              enum 'in_app'
  body                 text
  is_read              bool
  created_at           datetime
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/parties` | Customer recipient lookup |
| `@chthonic/templating` | Liquid render + locale filters |
| `@chthonic/audit` | Audit on send |
| `Amazon.SimpleEmailV2` | SES |
| `Twilio` | SMS |
| `FirebaseAdmin` | FCM |

## Extension points

| Hook | Use |
|---|---|
| `INotificationPublisher` registration | Subscribe handlers per template-key |
| Add a new channel | Implement `INotificationChannel` + register |
| Custom templates | Add `Templates/<key>.liquid` embedded resources |
| Asset service-due (v0.3.0+) | Register `IAssetServiceIntervalProvider` to drive the `AssetServiceDue` milestone |

## Consuming this library

```csharp
using Chthonic.Notifications;
builder.Services.AddChthonicNotifications(builder.Configuration);
app.MapNotificationEndpoints();
```

```tsx
import { setCommunicationsHttp, CommunicationsInbox } from '@chthonicsystems/notifications';
setCommunicationsHttp(httpService);

<CommunicationsInbox userId={userId} />
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`liquid-templates.md`](liquid-templates.md), [`reminders.md`](reminders.md), [`open-entry-watchdog.md`](open-entry-watchdog.md), [`communications-panel.md`](communications-panel.md).
- Library repo: [chthonicsystems/notifications](https://github.com/chthonicsystems/notifications).
- [RFC 0009](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0009-notifications-and-messaging.md), [RFC 0025](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md) (watchdog hoist).

## Version history

- **0.3.1** (2026-07-20) — Patch: `AssetServiceDueRecord` now carries `CustomerEmail` + `CustomerName` (v0.3.0 omitted them, leaving the `asset_service_due` template without a recipient). No API-shape break beyond the added record fields.
- **0.3.0** (2026-07-20) — Adds the `AssetServiceDue` reminder milestone (F12 service-interval reminders, [RFC 0033](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0033-service-interval-reminders.md)). Ships `AssetServiceDueReminderRule : IReminderRule` (idles with no provider registered) plus the `IAssetServiceIntervalProvider` extension point and `AssetServiceDueRecord`. Fires `DueSoon` at a 14-day lookahead and `Due` on the service date when no booking exists; day-bucketed idempotency via `NotificationRequest.MilestoneKey` (`AssetServiceDue-{soon|due}-{yyyy-MM-dd}`) re-arms each service cycle. Reminder template is consumer-registered (`asset_service_due`); no embedded body shipped. TorqueTech registers `TTAssetServiceIntervalProvider`. v1 deferrals: per-tenant lookahead is a constant 14 days, km-based interval stored but unused (time-based only), booking-window suppression / job-close `LastServiceAt` auto-set / Config-Hub section are follow-ups. Existing v0.1.x / v0.2.x consumers continue to work unchanged.
- **0.2.0** (2026-05-23) — Adds `IOpenEntryWatchdog` + `OpenEntryHit` + `OpenEntryWatchdogScheduler` sub-daily watchdog primitive. Sibling of the existing daily `ReminderScheduler` — runs alongside, not in place of. Idempotency reuses the existing `notification_log` composite index `(entity_type, entity_id, reminder_milestone)` with a per-UTC-day-bucketed key. Zero new schema. Hoisted from TT-side per [RFC 0025 § 10 Alternative 3](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md#alternative-3-tt-side-watchdog-only-no-chthonicnotifications-bump) so F4 (PR 02) + F12 (PR 13 — RFC 0033) + sister-products inherit the primitive. `INotificationLogger.WasMilestoneFiredAsync(int, string, string)` string-keyed overload added (default-method, backward-compat). `NotificationLogEntry.MilestoneKey` optional positional-record field added. Existing v0.1.x consumers continue to work unchanged.
- **0.1.0** (2026-05-17) — Initial release.
