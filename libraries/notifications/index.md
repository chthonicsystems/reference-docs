---
library: notifications
package-nuget: Chthonic.Notifications
package-npm: '@chthonicsystems/notifications'
version: 0.2.0
related-rfcs: [0009, 0025]
related-libs: [tenant, parties, templating, audit]
last-verified: 2026-05-23
tags: [communications, multi-channel, liquid, reminders, watchdog]
summary: Multi-channel publisher (push/email/SMS/in-app) + Liquid templates + daily reminders + sub-daily open-entry watchdog primitive + comms.
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

- **0.2.0** (2026-05-23) — Adds `IOpenEntryWatchdog` + `OpenEntryHit` + `OpenEntryWatchdogScheduler` sub-daily watchdog primitive. Sibling of the existing daily `ReminderScheduler` — runs alongside, not in place of. Idempotency reuses the existing `notification_log` composite index `(entity_type, entity_id, reminder_milestone)` with a per-UTC-day-bucketed key. Zero new schema. Hoisted from TT-side per [RFC 0025 § 10 Alternative 3](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md#alternative-3-tt-side-watchdog-only-no-chthonicnotifications-bump) so F4 (PR 02) + F12 (PR 13 — RFC 0033) + sister-products inherit the primitive. `INotificationLogger.WasMilestoneFiredAsync(int, string, string)` string-keyed overload added (default-method, backward-compat). `NotificationLogEntry.MilestoneKey` optional positional-record field added. Existing v0.1.x consumers continue to work unchanged.
- **0.1.0** (2026-05-17) — Initial release.
