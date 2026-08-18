---
library: notifications
version: 0.1.0
related-rfcs: [0009]
last-verified: 2026-05-22
tags: [notifications, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/notifications`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.Notifications" Version="0.1.0" />
```

```json
"@chthonicsystems/notifications": "0.1.0"
```

## 2. Configure secrets

```bash
AWS_REGION=ap-southeast-1                    # SES region
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
FROM_EMAIL=admin@chthonicsystems.com         # verified in SES

SMS_PROVIDER=sns                             # production only — omit for dev/beta (logs OTP instead of sending)
SMS_SENDER_ID=MyBrand                        # optional SNS alphanumeric sender ID

FIREBASE_SERVICE_ACCOUNT_JSON=...            # path or JSON string
```

## 3. Register DI

```csharp
using Chthonic.Notifications;
builder.Services.AddChthonicNotifications(builder.Configuration);
app.MapNotificationEndpoints();
```

`AddChthonicNotifications` registers the publisher, all four channel services, the template renderer, and the `ReminderScheduler` background service.

## 4. Publish

```csharp
public class InvoiceSendService(INotificationPublisher publisher)
{
    public async Task SendAsync(Invoice invoice)
    {
        await publisher.PublishAsync(new NotificationRequest
        {
            SystemId = invoice.SystemId,
            Channel = NotificationChannel.Email,
            Recipient = invoice.Customer.Email,
            TemplateKey = "invoice.sent",
            EntityType = "Invoice",
            EntityId = invoice.InvoiceId,
            Data = new { Invoice = invoice, System = system },
        });
    }
}
```

## 5. Frontend — communications inbox

```tsx
import { setCommunicationsHttp, CommunicationsInbox } from '@chthonicsystems/notifications';
setCommunicationsHttp(httpService);

<CommunicationsInbox userId={userId} />
```

## Related

- [`multi-channel-publisher.md`](multi-channel-publisher.md), [`liquid-templates.md`](liquid-templates.md), [`reminders.md`](reminders.md).
