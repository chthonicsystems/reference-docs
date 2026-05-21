---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, extension-points]
summary: Extension points — IBookingNotificationDispatcher, IBookingLimitService, IBookingAvailabilityService override.
---

# Extension points

| Hook | Use |
|---|---|
| `IBookingNotificationDispatcher` (port) | Wire to consumer notification orchestrator |
| `IBookingLimitService` (port) | Tier-aware daily booking limit |
| `IBookingAvailabilityService` (override) | Custom availability rules |
| `setBookingHttp`, `setBookingUseAuth` (npm) | Peer-injection adapters |

## Custom availability

```csharp
public class WeatherAwareAvailability : IBookingAvailabilityService
{
    public async Task<List<TimeSlot>> GetSlotsAsync(int serviceId, DateOnly date)
    {
        var defaultSlots = await base.GetSlotsAsync(serviceId, date);
        var weather = await _weather.GetForecastAsync(date);
        if (weather.IsBadWeather) return [];   // marina cancels outdoor work
        return defaultSlots;
    }
}

builder.Services.AddScoped<IBookingAvailabilityService, WeatherAwareAvailability>();
```

## Booking → Job conversion handler

When a booking is approved → Job is created via the consumer's `IJobService`. Booking library doesn't directly call work library; the consumer wires a handler.

## Related

- [`availability-service.md`](availability-service.md), [`extension-hooks.md`](extension-hooks.md).
