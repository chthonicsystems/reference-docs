---
library: work
package-nuget: Chthonic.Work
package-npm: '@chthonicsystems/work'
version: 0.3.0
related-rfcs: [0001, 0022, 0025, 0037]
related-libs: [tenant, parties, assets, views, notes, audit, notifications]
last-verified: 2026-05-23
tags: [work-spine, jobs, qc-signoff, labour-clocking]
summary: Slimmed Job spine — Job + JobMechanic + auto-comments + status validation + v0.2.0 QC sign-off vocabulary + v0.3.0 LabourEntry timeline (clock-in/out per mechanic).
---

# `@chthonicsystems/work` / `Chthonic.Work`

The slimmed Job spine — the core operational entity for service jobs across products. Notes/files/views/communications were intentionally split out (see PR 13 of the extraction sequence).

## Purpose

A `Job` is the unit of work a tenant performs. Cross-product:
- TT — vehicle service jobs.
- MarineDeck — vessel service / berth work orders.
- FlowLift — forklift maintenance jobs.
- PetCare — exam / treatment encounters.

`@chthonic/work` owns: Job entity, multi-mechanic assignment, approvals, auto-comment generation on state transitions, status transition validation.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IJobService` / `JobService` | CRUD over Job |
| `IJobMechanicService` | Multi-mechanic assignment |
| `IJobApprovalService` | Approval workflow |
| `IAutoCommentGenerator` | Auto-emits comments on state transitions |
| `IJobStatusTransitionValidator` | Validates status changes |
| `IQcSignoffService` (v0.2.0+) | QC sign-off lifecycle (start / submit / rework). See [qc-signoff.md](qc-signoff.md). |
| `ILabourClockService` (v0.3.0+) | Per-mechanic clock-in / clock-out timeline. Overlap-detect on user; idempotent close. See [labour-clocking.md](labour-clocking.md). |
| `LabourClockOverlapException` (v0.3.0+) | Typed exception with `OpenLabourEntryId` + `OpenJobId` for 409 mapping |
| `MapChthonicWorkEndpoints` | (sister-product ready; TT keeps its own) |
| `services.AddChthonicWork()` | DI entry point — auto-registers all services above |

**Domain entities:** `Job`, `JobMechanic`, `JobApproval`, `JobComment`, `QcSignoff` / `QcSignoffItemResult` / `QcRework` (v0.2.0+), `LabourEntry` (v0.3.0+; `[AuditParent]` rollup to Job, mirrors the `JobMechanic` precedent). `JobApproval`/`JobPartsInstalled`/`JobLaundry`/`JobInspection` were dropped as dead code in PR 13.

### npm

| Export | Role |
|---|---|
| Types | `Job`, `JobStatus`, `JobMechanicAssignment`, `QcSignoff` / `QcSignoffItemResult` / `QcRework` / `QcSignoffStatus` (v0.2.0+), `LabourEntry` (v0.3.0+) |
| Future | Job-related hooks + components when consumer-extracted |

## Schema

```
job
  job_id          int PK
  system_id       int
  job_number      varchar(50)
  asset_id        int FK → asset (polymorphic-base; cast to subtype)
  customer_id     int FK
  estimate_id     int FK?     (FK-only nav; no nav property)
  invoice_id      int FK?     (FK-only nav)
  booking_id      int FK?     (FK-only nav)
  status          enum 'InProgress', 'Completed', 'Closed'
  total_amount    decimal(10,2)
  currency        char(3)
  meter_reading   int?
  due_date        date?
  scheduled_date  datetime?
  created_at      datetime
  deleted_at      datetime?

job_mechanic
  job_id    int FK
  user_id   int FK
  assigned_at datetime
  PK (job_id, user_id)

job_comment
  comment_id  int PK
  job_id      int FK
  user_id     int FK?      (null for system-generated)
  body        text
  is_system   bool
  created_at  datetime
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/parties` | Customer FK |
| `@chthonic/assets` | Asset FK + polymorphic-base nav |
| `@chthonic/views` | Per-job custom fields via entity_field_value |
| `@chthonic/notes` | Per-job notes |
| `@chthonic/audit` | Audit on status / mechanic / field changes |

## Extension points

| Hook | Use |
|---|---|
| `IJobStatusTransitionValidator` | Override transition rules per product |
| `IAutoCommentGenerator` | Customise auto-comment text on transitions |
| `IJobNumberGenerator` | Customise job-number format per tenant |

## Consuming this library

```csharp
builder.Services.AddChthonicWork();
// TT keeps /api/jobs/* — does NOT mount library endpoints.
```

```csharp
// Cross-library consumer cast (see platform/extension-patterns.md § 6):
var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(...);
var vehicle = (Vehicle)job.Asset;     // TT-side downcast
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`job-spine.md`](job-spine.md), [`auto-comments.md`](auto-comments.md), [`status-transitions.md`](status-transitions.md), [`cross-library-asset-fk.md`](cross-library-asset-fk.md).
- [`qc-signoff.md`](qc-signoff.md) (v0.2.0+), [`labour-clocking.md`](labour-clocking.md) (v0.3.0+).
- Library repo: [chthonicsystems/work](https://github.com/chthonicsystems/work).
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md), [RFC 0022](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md), [RFC 0025](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md).

## Version history

- **0.4.3** (2026-05-24) — Auto-fail rework reason routed through `INoteService.CreateNoteAsync` (`IsAutoGenerated = false`) instead of the `AutoCommentGenerator` auto-comment path. Symmetric with v0.4.2's supervisor `reworkOverrideReason`. Both paths now produce a regular note authored by the supervisor.
- **0.4.2** (2026-05-24) — Supervisor's `reworkOverrideReason` (the all-pass-but-still-rework path) becomes a regular note via `INoteService.CreateNoteAsync` rather than a synthetic auto-comment. Restores authorship attribution.
- **0.4.1** (2026-05-24) — `SubmitSignoffAsync` gains optional `reworkOverrideReason` parameter. When all items pass but the supervisor still wants the cycle treated as rework, this string captures the reason. Persisted on `qc_signoff` and surfaced in the timeline.
- **0.4.0** (2026-05-24, BREAKING) — Simplified QC lifecycle. `JobStatus` enum collapses to `InProgress | Completed | Closed`; `PendingQcSignoff` and `QcPassed` removed. `Reworked` is no longer a `JobStatus` — it's a `QcSignoffStatus` only (the job stays `InProgress` after a rework cycle, with `qc_signoff.status = Reworked` carrying the lifecycle signal). `IJobStatusTransitionValidator` consumers must drop references to retired statuses. See [RFC 0022 § 13 Amendment 2](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md#13-amendment-2--f1cf1d-state-machine-simplification--reopen-tracking--rework-badge-2026-05-24).
- **0.3.1** (2026-05-23) — Supervisor note overrides the auto-generated rework reason when both are present (the supervisor's wording is more specific than "Item N failed"). Backwards compatible — auto-reasons still used when no supervisor note.
- **0.3.0** (2026-05-23) — Adds `LabourEntry` per-mechanic clock-in / clock-out timeline entity (`[AuditParent]` rollup to Job; one row per work session); `ILabourClockService` (overlap-detect within UserId across all jobs; idempotent ClockOut; ListByJob; GetOpenForUser); `LabourClockOverlapException` (typed for 409 mapping). Empty `_ChthonicWork_0003_LabourEntry` lib migration per coexistence pattern; consumer-side migration owns the `CREATE TABLE labour_entry` DDL. NPM `LabourEntry` TypeScript interface added. No JobStatus changes.
- **0.2.0** (2026-05-23) — Adds QC sign-off vocabulary (RFC 0022 / F1). JobStatus + 3 (`PendingQcSignoff`, `Reworked`, `QcPassed`). New `IJobStatusTransitionValidator` extension hook. `QcSignoff` / `QcSignoffItemResult` / `QcRework` entities. `IQcSignoffService`.
- **0.1.0** (2026-05-18) — Initial release.
