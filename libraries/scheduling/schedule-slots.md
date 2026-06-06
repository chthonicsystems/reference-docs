---
library: scheduling
version: 0.1.0
last-verified: 2026-06-06
tags: [schedule-slot, conflict-detection, mysql-trigger, force-override]
summary: ScheduleSlot deep-ref — DB-level non-overlap enforcement via MySQL trigger; force-override via session variable + permission; status state machine; cross-library FK-only typing on JobId/BookingId.
---

# ScheduleSlot

A staff-initiated assignment of a Job (or Booking) to a Resource for a specific time window.

## Schema

| Column | Type | Notes |
|---|---|---|
| `schedule_slot_id` | INT PK | AUTO_INCREMENT |
| `resource_id` | INT FK | `fk_schedule_slot_resource` → `resource(resource_id) ON DELETE RESTRICT`. Lib-known nav. |
| `system_id` | INT | Denormalised from Resource for fast filter on hot list query. Set server-side at insert. |
| `job_id` | INT NULL | Cross-library FK-only — references `Chthonic.Work.Domain.Job` at runtime; no nav property. |
| `booking_id` | INT NULL | Cross-library FK-only — references `Chthonic.Booking.Domain.Booking` at runtime; no nav property. |
| `start_at` | DATETIME(6) | Window start (inclusive). |
| `end_at` | DATETIME(6) | Window end (exclusive). |
| `status` | VARCHAR(20) | Enum stored as display string: `"Reserved" | "In Progress" | "Completed" | "Cancelled"`. |
| `created_at` / `updated_at` | DATETIME(6) | Standard audit timestamps. |

**Indexes:**
- `idx_schedule_slot_resource_time (resource_id, start_at, end_at)` — supports the conflict trigger's overlap-check WHERE clause + the `GET /api/scheduling/schedule-slots?from=&to=` query + F17 bay-utilization aggregation.
- `idx_schedule_slot_system_start (system_id, start_at)` — tenant-scoped list.
- `idx_schedule_slot_job_id (job_id)` — reverse-lookup "this job's slots" projection (replaces `Job.ScheduledDate` per RFC 0029 § 12 Amendment 1 12e).

## Cross-library FK-only typing

Per [RFC 0008 amendment](../../../architecture/rfcs/0008-cross-library-fk.md): `JobId` and `BookingId` are `int?` columns with **no nav property**. The lib never compile-time depends on `@chthonic/work` or `@chthonic/booking`. Consumer apps that want a nav can opt in via extension classes in their own assembly.

## Status state machine

```
Reserved ──► InProgress ──► Completed
   │              │
   ▼              ▼
Cancelled    Cancelled
```

- `Reserved` (default at creation) — slot booked but work hasn't started.
- `InProgress` — mechanic clocked in / work started.
- `Completed` — terminal happy-path state.
- `Cancelled` — terminal failure state. **Excluded from conflict detection** (a cancelled past slot doesn't block a new live one).

State transitions via dedicated endpoints (`POST /api/scheduling/schedule-slots/{id}/cancel`, `POST .../complete`). Service-layer methods `CancelAsync` / `CompleteAsync` fire `IScheduleSlotEventBus.PublishCancelledAsync` / `PublishCompletedAsync`.

## Conflict detection — DB-level MySQL trigger

The lib's `0001_Initial` migration creates two MySQL triggers:

```sql
CREATE TRIGGER schedule_slot_no_overlap_insert
BEFORE INSERT ON schedule_slot
FOR EACH ROW
BEGIN
  IF (@sx_bypass_overlap_check IS NULL OR @sx_bypass_overlap_check = 0) THEN
    IF NEW.status NOT IN ('Cancelled') AND EXISTS (
      SELECT 1 FROM schedule_slot
      WHERE resource_id = NEW.resource_id
        AND status NOT IN ('Cancelled')
        AND NEW.start_at < end_at
        AND NEW.end_at > start_at
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'slot-conflict';
    END IF;
  END IF;
END
```

A mirror `BEFORE UPDATE` trigger applies the same logic, additionally excluding the row being updated from the overlap check.

**Why DB-level?** MySQL lacks Postgres' `EXCLUDE USING gist` constraint. App-layer rejection has a race window between the SELECT-then-INSERT pattern; the trigger is the only race-free option. Per [RFC 0029 § 12 Amendment 1 12d](../../../architecture/rfcs/0029-dispatch-board.md#12d-conflict-policy--db-level-mysql-trigger--force-override-permission-closes--9-question-3).

**Trigger signal translation**: `DispatchBoardService` catches `DbUpdateException` whose inner exception's message contains `"slot-conflict"` and translates to `ScheduleSlotConflictException`. Endpoints map that to HTTP 409 `{ errorCode: "slot-conflict" }`.

## Force-override (`?force=true`)

Admins with the `action:override-slot-conflict` permission can bypass the trigger via:

```
POST /api/scheduling/schedule-slots?force=true
```

Service-layer flow:

1. Caller passes `force=true` AND has the permission.
2. Service consults `IDispatchBoardPolicyProvider.AllowOverlap(resourceType, existing, incoming)`. Default `HardRejectOverlapPolicy` returns `false`; sister-products may override per-resource-type.
3. If both agree, service issues `SET @sx_bypass_overlap_check = 1` BEFORE the INSERT/UPDATE.
4. Trigger short-circuits when the session var is set.
5. Service issues `SET @sx_bypass_overlap_check = NULL` AFTER the statement completes (success or failure).

The session variable is per-connection and per-statement-batch; a forced insert never accidentally bypasses checks on subsequent statements.

## MySQL prerequisite

The lib's triggers are CREATE TRIGGER statements which require `SUPER` privilege OR `log_bin_trust_function_creators = 1` at the server level when binary logging is enabled.

**TT dev DB setup:** one-time `SET GLOBAL log_bin_trust_function_creators = 1` as root. Persists for the container lifetime.

**TT prod/beta:** the same setting needs to be applied to MySQL/MariaDB at the server level (e.g. via `my.cnf`). MariaDB on beta typically has it enabled by default.

## Cross-references

- [Architecture](architecture.md)
- [Resource entity](resources.md)
- [Extension points — IDispatchBoardPolicyProvider](extension-points.md#idispatchboardpolicyprovider--overlap-policy)
- [Dispatch-board UX contract](dispatch-board.md)
- [RFC 0029](../../../architecture/rfcs/0029-dispatch-board.md)
