---
library: work
package-nuget: Chthonic.Work
package-npm: '@chthonicsystems/work'
version: 0.1.0
related-rfcs: [0001]
related-libs: [tenant, parties, assets, views, notes, audit]
last-verified: 2026-05-22
tags: [work-spine, jobs]
summary: Slimmed Job spine — Job + JobMechanic + JobApproval + auto-comments + status validation.
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
| `MapChthonicWorkEndpoints` | (sister-product ready; TT keeps its own) |
| `services.AddChthonicWork()` | DI entry point |

**Domain entities:** `Job`, `JobMechanic`, `JobApproval`, `JobComment`. `JobApproval`/`JobPartsInstalled`/`JobLaundry`/`JobInspection` were dropped as dead code in PR 13.

### npm

| Export | Role |
|---|---|
| Types | `Job`, `JobStatus`, `JobMechanicAssignment` |
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
- Library repo: [chthonicsystems/work](https://github.com/chthonicsystems/work).
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md).
