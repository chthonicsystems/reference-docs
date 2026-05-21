---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, publisher, channels]
summary: INotificationPublisher — single send API across email/SMS/push/in-app.
---

# Multi-channel publisher

`INotificationPublisher.PublishAsync(req)` is the single entry point. The publisher dispatches to the channel matching `req.Channel`.

## NotificationRequest

```csharp
public record NotificationRequest
{
    public required int SystemId { get; init; }
    public required NotificationChannel Channel { get; init; }
    public required string Recipient { get; init; }    // email / mobile / fcm token / user id
    public required string TemplateKey { get; init; }   // 'invoice.sent', 'booking.approved', ...
    public string? EntityType { get; init; }
    public int? EntityId { get; init; }
    public string? ReminderMilestone { get; init; }
    public required object Data { get; init; }          // template context
}
```

## Channel routing

```csharp
public class NotificationPublisher
{
    private readonly Dictionary<NotificationChannel, INotificationChannel> _channels;

    public async Task PublishAsync(NotificationRequest req)
    {
        // Idempotency check (for reminder milestones)
        if (await IsAlreadySentAsync(req)) return;

        var channel = _channels[req.Channel];
        var rendered = await _renderer.RenderAsync(req.TemplateKey, req.Channel, req.Data);

        await channel.SendAsync(req with { /* attach rendered */ });
        await _logger.LogAsync(req, NotificationLogStatus.Sent);
    }
}
```

## Channels

| Channel | Implementation |
|---|---|
| `Email` | `EmailSenderService` → SES |
| `Sms` | `TwilioSmsService` → Twilio |
| `Push` | `FcmPushService` → Firebase |
| `InApp` | `InAppCommunicationService` → `communication` table |

## Related

- [`liquid-templates.md`](liquid-templates.md), [`extension-points.md`](extension-points.md).
