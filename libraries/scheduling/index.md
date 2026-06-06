---
library: scheduling
package-nuget: Chthonic.Scheduling
package-npm: '@chthonicsystems/scheduling'
version: 0.1.0
related-rfcs: [0029]
related-libs: [tenant, audit, work, booking, ui, mobile-runtime]
last-verified: 2026-06-06
tags: [scheduling, dispatch, resource, drag-drop]
summary: Vertical-agnostic staff-initiated resource scheduling — Resource + ScheduleSlot + IDispatchBoardService + 3 extension hooks. Distinct from `@chthonic/booking` (customer-initiated).
---

# `@chthonicsystems/scheduling` / `Chthonic.Scheduling`

The platform's 26th library — vertical-agnostic staff-initiated resource scheduling. TorqueTech consumes for bay/lift dispatch, MarineDeck for slip dispatch, FlowLift for forklift bay dispatch, PetCare for exam-room dispatch.

Per [RFC 0029](../../../architecture/rfcs/0029-dispatch-board.md) (with [§ 12 Amendment 1](../../../architecture/rfcs/0029-dispatch-board.md#12-amendment-1--implementation-decisions-and-divergences-2026-06-06)).

## Purpose

- Resource entity (vertical-agnostic; ResourceType string discriminator) — bay, lift, ramp, slip, exam room.
- ScheduleSlot entity — Job XOR Booking × Resource × time-window. Cross-library FK-only typing.
- IDispatchBoardService for query/assign/reassign/release/cancel/complete operations.
- DB-level non-overlap enforcement via MySQL trigger; admin override via `?force=true` + `action:override-slot-conflict` permission.
- Three extension hooks for per-product customization (resource taxonomy, event bus, overlap policy).
- Composable React subcomponents over `@dnd-kit/core` for hand-built dispatch boards.

## Public surface

### .NET

| Type | Role |
|---|---|
| `Domain.Resource` | Schedulable resource. PK `ResourceId`. FK-only `SystemId`. String `ResourceType`. |
| `Domain.ScheduleSlot` | Time-windowed assignment. PK `ScheduleSlotId`. FK Resource (lib-known nav). FK-only `JobId` / `BookingId` (no nav, cross-library). |
| `Domain.ResourceType` | Static class with `Bay`, `Lift`, `Ramp` constants. |
| `Domain.ScheduleSlotStatus` | Enum: `Reserved | InProgress | Completed | Cancelled`. |
| `Services.IDispatchBoardService` | Primary service surface; methods: `GetBoardAsync`, `AssignAsync`, `ReassignAsync`, `ReleaseAsync`, `CancelAsync`, `CompleteAsync`. |
| `Services.ScheduleSlotConflictException` | Thrown on trigger-rejected overlap; caller maps to HTTP 409. |
| `Extensions.IDbContextProvider` | Consumer-required: bridge to consumer's DbContext. |
| `Extensions.IResourceTypeProvider` | Per-product extension hook for resource taxonomy. |
| `Extensions.IScheduleSlotEventBus` | Pub/sub seam for slot lifecycle events. |
| `Extensions.IDispatchBoardPolicyProvider` | Per-resource-type overlap-policy override. |
| `ServiceCollectionExtensions.AddChthonicScheduling` | DI registration entry point. |
| `ServiceCollectionExtensions.MapChthonicSchedulingEndpoints` | Mounts CRUD endpoints under `/api/scheduling/{resources,schedule-slots}`. |

### TypeScript

| Symbol | Role |
|---|---|
| `setSchedulingHttp(adapter)` | Peer injection: register HTTP adapter at app startup. |
| `setSchedulingUseAuth(hook)` | Peer injection: register useAuth hook. |
| `useResources(systemId)` | React hook; fetches active Resources. |
| `useScheduleSlots(systemId, from, to)` | React hook; fetches slots in window. |
| `useAssignSlot()` / `useReassignSlot()` / `useReleaseSlot()` / `useCancelSlot()` / `useCompleteSlot()` | Mutation hooks. |
| `<DispatchBoardLayout>` | Top-level orchestrator. Wraps `<DndContext>` around lanes. |
| `<ResourceLane>` | Single Resource header + slot column. dnd-kit drop target. |
| `<SlotCard>` | Generic slot tile with optional render-prop preview. dnd-kit draggable. |
| `<TimeGridHeader>` | Date/hour ruler above lanes. |

## Schema delta

v0.1.0:
- New table `resource` (resource_id PK, system_id, name, resource_type, is_active, display_order, created_at, updated_at; unique `(system_id, name)`).
- New table `schedule_slot` (schedule_slot_id PK, resource_id FK, system_id, job_id FK-only, booking_id FK-only, start_at, end_at, status, created_at, updated_at; index `(resource_id, start_at, end_at)`).
- New MySQL triggers `schedule_slot_no_overlap_insert` + `schedule_slot_no_overlap_update` enforcing non-overlap on `(resource_id, [start_at, end_at))` excluding Cancelled rows.
- Force-override via session variable `@sx_bypass_overlap_check = 1`.

## Cross-references

- [Architecture diagram](architecture.md)
- [Consumption pattern (TT worked example)](consumption.md)
- [Extension points reference](extension-points.md)
- [Resource entity deep-ref](resources.md)
- [ScheduleSlot conflict-detection deep-ref](schedule-slots.md)
- [Dispatch-board UX contract (dnd-kit)](dispatch-board.md)
- [`@chthonic/booking` — customer-side counterpart](../booking/index.md)
- [`@chthonic/work` v0.8.0 BREAKING — drops `Job.ScheduledDate`](../work/index.md)
- [RFC 0029](../../../architecture/rfcs/0029-dispatch-board.md)
