---
library: booking
version: 0.2.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [booking, time-slots, off-days]
summary: ServiceTimeSlot + ServiceOffDay — per-service availability windows + closures.
---

# Time slots + off-days

Two simple entities back the availability calculator.

## ServiceTimeSlot

```sql
CREATE TABLE service_time_slot (
    slot_id INT PRIMARY KEY AUTO_INCREMENT,
    service_id INT NOT NULL,
    day_of_week TINYINT NOT NULL,   -- 0=Sun, 6=Sat
    start_time TIME NOT NULL,
    end_time TIME NOT NULL
);
```

A service can have multiple slots per day:

```
service_id=1, day_of_week=1, 09:00, 12:00
service_id=1, day_of_week=1, 14:00, 17:00
```

Means Monday morning AND afternoon, with a midday break.

## ServiceOffDay

```sql
CREATE TABLE service_off_day (
    off_day_id INT PRIMARY KEY AUTO_INCREMENT,
    service_id INT NOT NULL,
    date DATE NOT NULL,
    reason VARCHAR(200) NULL
);
```

Per-service closures (holidays, sick days, training). System-wide closures (every service closed on Christmas Day) require N rows (one per service); future RFC may add tenant-wide off-days.

## Endpoints

```
GET    /api/services/{serviceId}/time-slots
PUT    /api/services/{serviceId}/time-slots         # bulk replace
GET    /api/services/{serviceId}/off-days
POST   /api/services/{serviceId}/off-days
DELETE /api/services/{serviceId}/off-days/{id}
```

(Endpoints owned by Booking; service-side is a read-only join.)

## Related

- [`availability-service.md`](availability-service.md).
