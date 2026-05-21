---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, frontend, react-hooks]
summary: useBookings + useBookingAvailability React hooks.
---

# Frontend hooks

The npm package ships two headless hooks (data only — UI is consumer-supplied because per-product pages render Vehicle/Vessel/Pet-specific JSX that's tightly coupled to consumer's domain).

## useBookings

```tsx
const { data, total, page, setPage, refresh, loading } = useBookings({
  systemId,
  mode: 'manage' | 'my' | 'pending',
  pageSize: 20,
  status?: BookingStatus,
});
```

Modes:

- `manage` — staff list of all bookings for the tenant.
- `my` — current customer's own bookings.
- `pending` — staff list of Pending bookings only.

## useBookingAvailability

```tsx
const { slots, loading } = useBookingAvailability(systemId, serviceId, selectedDate);
// slots: [{ start: "09:00", end: "09:30" }, ...]
```

Polls when `selectedDate` changes. Debounced.

## Bootstrap requirement

```tsx
import { setBookingHttp, setBookingUseAuth } from '@chthonicsystems/booking';

setBookingHttp(httpService);    // call once at app start
setBookingUseAuth(useAuth);
```

Without these, the hooks throw a helpful "BookingHttpAdapter not registered" error.

## Why not full pages

Booking pages render Vehicle / Vessel / Pet-specific JSX (e.g. `<VehicleCard>` shows make + model + Vin). Lifting full pages would force the library to know about consumer-specific components. v0.2.0 ships hooks only; pages stay consumer-side.

Future v0.3.0+ may lift bare-bones pages once `@chthonicsystems/ui` ships enough cross-product asset-display primitives.

## Related

- [`consumption.md`](consumption.md), [`extension-hooks.md`](extension-hooks.md).
