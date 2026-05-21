---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, extension-hooks]
summary: Two consumer ports — IBookingNotificationDispatcher, IBookingLimitService.
---

# Extension hooks

| Port | Use |
|---|---|
| `IBookingNotificationDispatcher` | Five methods: NotifyCreated / Approved / Rejected / Cancelled / Updated |
| `IBookingLimitService` | `CanCreateBookingAsync(systemId)` — tier-aware quota gate |

## IBookingNotificationDispatcher

```csharp
public interface IBookingNotificationDispatcher
{
    Task NotifyCreatedAsync(int bookingId);
    Task NotifyApprovedAsync(int bookingId);
    Task NotifyRejectedAsync(int bookingId);
    Task NotifyCancelledAsync(int bookingId);
    Task NotifyUpdatedAsync(int bookingId);
}
```

Consumer adapter delegates to `@chthonic/notifications` orchestrator.

## IBookingLimitService

```csharp
public interface IBookingLimitService
{
    Task<bool> CanCreateBookingAsync(int systemId);
}
```

Consumer adapter delegates to `@chthonic/tenant.ILimitService.CheckQuotaAsync("MaxBookingsPerDay", systemId)`.

## Related

- [`consumption.md`](consumption.md).
