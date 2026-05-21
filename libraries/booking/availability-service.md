---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, availability]
summary: BookingAvailabilityService — slot calculation respecting time slots + off-days + existing bookings.
---

# Availability service

`IBookingAvailabilityService.GetSlotsAsync(serviceId, date)` computes available time slots for a service on a given date.

## Rules

1. **Time slots** — start with `service_time_slot` rows for the service's `day_of_week`.
2. **Off-days** — if `service_off_day(service_id, date)` row exists → return empty list.
3. **Existing bookings** — exclude time ranges occupied by Pending/Approved bookings.

## Algorithm

```
function GetSlotsAsync(serviceId, date):
    if exists(service_off_day, service_id, date): return []
    slots = service_time_slot[service_id, day_of_week(date)]
    bookings = booking[service_id, date(scheduled_at) == date, status in (Pending, Approved)]
    return slots - bookings
```

Time-slot intervals are 30-minute granularity by default (configurable per service).

## Frontend usage

```tsx
const slots = useBookingAvailability(systemId, serviceId, selectedDate);
// slots = [{ start: "09:00", end: "09:30" }, { start: "10:00", end: "10:30" }, ...]
```

## Server-rendering

`/api/bookings/availability?serviceId=X&date=YYYY-MM-DD` returns the same data. Useful for SSR / mobile.

## BookingResponse re-hydration (PR 14c)

After PR 14 dropped Booking.Estimate / Job / Invoice nav properties, the consumer-side projection re-hydrates via batch lookup:

```csharp
// In TT BookingEndpoints
var booking = await _db.Bookings.FirstAsync(b => b.BookingId == id);
await PopulateJobEstimateInvoiceInfo(booking, response);  // 4 batch DB roundtrips
```

`PopulateJobEstimateInvoiceInfo` queries jobs by `Booking.JobId`, estimates by `Booking.EstimateId`, invoices by `Job.InvoiceId`. Performance: O(1) per booking-detail render; O(N) if rendering N bookings (use bulk variant for list pages).

## Related

- [`time-slots.md`](time-slots.md), [`extension-points.md`](extension-points.md).
