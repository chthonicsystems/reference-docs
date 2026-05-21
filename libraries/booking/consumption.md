---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/booking`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Booking" Version="0.1.0" />
```

```json
"@chthonicsystems/booking": "0.2.0"
```

## 2. Implement consumer ports

```csharp
public class TTBookingNotifyAdapter : IBookingNotificationDispatcher
{
    private readonly ITTNotificationOrchestrator _notify;
    public TTBookingNotifyAdapter(ITTNotificationOrchestrator notify) => _notify = notify;
    public Task NotifyApprovedAsync(int bookingId) => _notify.NotifyBookingApprovedAsync(bookingId);
    public Task NotifyRejectedAsync(int bookingId) => _notify.NotifyBookingRejectedAsync(bookingId);
    // ...
}

public class TTBookingLimitService : IBookingLimitService
{
    private readonly ISystemLimitService _limits;
    public TTBookingLimitService(ISystemLimitService limits) => _limits = limits;
    public Task<bool> CanCreateBookingAsync(int systemId) =>
        _limits.CheckQuotaAsync("MaxBookingsPerDay", systemId);
}

builder.Services.AddScoped<IBookingNotificationDispatcher, TTBookingNotifyAdapter>();
builder.Services.AddScoped<IBookingLimitService, TTBookingLimitService>();
```

## 3. Register Booking

```csharp
using Chthonic.Booking;
builder.Services.AddChthonicBooking();
```

## 4. Frontend bootstrap

```tsx
import { setBookingHttp, setBookingUseAuth } from '@chthonicsystems/booking';
import { httpService } from '../services/httpService';
import { useAuth } from '../contexts/AuthContext';

setBookingHttp(httpService);
setBookingUseAuth(useAuth);
```

## 5. Use the hooks

```tsx
import { useBookings, useBookingAvailability } from '@chthonicsystems/booking';

// Customer's own bookings
const { data, loading } = useBookings({ mode: 'my' });

// Slot availability
const slots = useBookingAvailability(systemId, serviceId, selectedDate);
```

## 6. Verification

- [ ] `POST /api/bookings` (TT-owned) creates a Pending booking + emits notification.
- [ ] Staff approving a Pending booking creates a Job + populates `booking.job_id`.
- [ ] `useBookingAvailability` returns slots respecting time slots + off-days + existing bookings.
- [ ] BookingResponse re-hydrates Job/Estimate/Invoice info via FK lookup (PR 14c helper).

## Related

- [`extension-points.md`](extension-points.md), [`availability-service.md`](availability-service.md), [`frontend-hooks.md`](frontend-hooks.md).
