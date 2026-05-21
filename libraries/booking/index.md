---
library: booking
package-nuget: Chthonic.Booking
package-npm: '@chthonicsystems/booking'
version: 0.2.0
related-rfcs: [0001]
related-libs: [tenant, parties, assets, work, notifications, audit]
last-verified: 2026-05-22
tags: [work-spine, scheduling, bookings]
summary: Customer bookings + time slots + off-days + availability service.
---

# `@chthonicsystems/booking` / `Chthonic.Booking`

Customer-initiated bookings — pre-job scheduling. A booking is a customer's request for a service at a specific date/time; staff approves → converts to a Job.

## Purpose

- Customer-facing booking flow: pick a service → check availability → submit.
- Per-service time slots (e.g. "Major Service" available 9-17 Mon-Fri).
- Off-days (holidays, closures).
- Availability service that respects time slots + existing bookings + off-days.
- State machine: `Pending` → `Approved` (creates Job) / `Rejected` / `Cancelled`.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IBookingService` | State transitions only — create stays in TT |
| `IBookingAvailabilityService` | Slot availability calculation |
| `IBookingNotificationDispatcher` (port) | Notify on state changes |
| `IBookingLimitService` (port) | Per-tier daily booking limit |
| `MapChthonicBookingEndpoints` | (sister-product ready) |
| `services.AddChthonicBooking()` | DI entry point |

### npm

| Export | Role |
|---|---|
| `useBookings({ mode: 'manage' \| 'my' \| 'pending' })` | Hook for staff manage / customer my / pending lists |
| `useBookingAvailability(systemId, serviceId, date)` | Slot poller |
| `setBookingHttp`, `setBookingUseAuth` | Peer-injection adapters |

## Schema

```
booking
  booking_id      int PK
  system_id       int
  service_id      int FK
  asset_id        int FK?     (FK-only nav; cast at consumer site)
  customer_id     int FK?
  user_id         int FK?     (customer-portal user)
  status          enum 'Pending', 'Approved', 'Rejected', 'Cancelled'
  scheduled_at    datetime
  duration_min    int
  estimate_id     int FK?     (FK-only nav)
  job_id          int FK?     (FK-only nav; populated when approved → Job)
  notes           text?
  created_at      datetime

service_time_slot
  slot_id          int PK
  service_id       int FK
  day_of_week      int      0=Sunday, 6=Saturday
  start_time       time
  end_time         time

service_off_day
  off_day_id       int PK
  service_id       int FK
  date             date
  reason           varchar?
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/parties` | Customer FK |
| `@chthonic/assets` | Asset FK (FK-only typing) |
| `@chthonic/work` | Booking → Job conversion |
| `@chthonic/notifications` | State-change notifications |

## Extension points

| Hook | Use |
|---|---|
| `IBookingNotificationDispatcher` (port) | Wire to consumer's notification orchestrator |
| `IBookingLimitService` (port) | Tier-aware daily booking limit |
| `IBookingAvailabilityService` override | Custom availability rules |

## Consuming this library

```csharp
builder.Services.AddScoped<IBookingNotificationDispatcher, MyBookingNotifyAdapter>();
builder.Services.AddScoped<IBookingLimitService, MyBookingLimitAdapter>();
builder.Services.AddChthonicBooking();
// TT keeps /api/bookings/* — does NOT mount library endpoints.
```

```tsx
import { setBookingHttp, setBookingUseAuth, useBookings } from '@chthonicsystems/booking';
setBookingHttp(httpService);
setBookingUseAuth(useAuth);
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`availability-service.md`](availability-service.md), [`time-slots.md`](time-slots.md), [`extension-hooks.md`](extension-hooks.md), [`frontend-hooks.md`](frontend-hooks.md).
- Library repo: [chthonicsystems/booking](https://github.com/chthonicsystems/booking).
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md).
