---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, extension-points]
summary: Extension points — new channel, custom templates, custom reminder milestones.
---

# Extension points

| Hook | Use |
|---|---|
| `INotificationChannel` | Add a new channel (e.g. WhatsApp via Twilio Business API) |
| `Templates/{key}.liquid` | Add custom template — drop in as embedded resource |
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

## Related

- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`reminders.md`](reminders.md).
