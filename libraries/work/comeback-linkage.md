---
library: work
related-rfcs: [0028, 0036]
last-verified: 2026-07-21
tags: [comeback, warranty, self-fk, f7, f15-foundation]
summary: v0.7.0 — Job.ParentJobId self-FK + Job.ComebackReason enum for comeback / warranty linkage. Data source for TorqueTech's comeback-rate report (F15, RFC 0036 — shipped 2026-07-21, PR 15).
---

# Comeback / warranty linkage

> **v0.7.0 (2026-05-27 / PR 07)** — `ComebackReason` enum + `Job.ParentJobId` self-FK + `Job.ComebackReason` column + `Job.ParentJob` nav.
> RFC 0028 § 4 + § 12 Amendment 1 + § 13 Amendment 2.

## Why a self-FK on `Job` (not a Custom Field via `@chthonic/views`)

The parent / reason pair is **core data lineage**, not tenant-configurable
business rules. Gating it as a Custom Field would mean tracking comebacks
for some tenants but not others, which makes the F15 comeback-rate report
(RFC 0036) unreliable across the platform. The decision mirrors PR 06's
`Job.Priority` reasoning (RFC 0027 § 12 Amendment 1).

## Public surface

### .NET — `Chthonic.Work`

```csharp
namespace Chthonic.Work.Domain;

public class Job
{
    // … existing fields …
    public int? ParentJobId { get; set; }
    public Job? ParentJob { get; set; }    // nav property
    public ComebackReason? ComebackReason { get; set; }
}

public enum ComebackReason
{
    Warranty = 0,
    Goodwill = 1,
    InsuranceClaim = 2,
    Other = 3,
}
```

### TypeScript — `@chthonicsystems/work`

```typescript
export enum ComebackReason {
  Warranty = 'Warranty',
  Goodwill = 'Goodwill',
  InsuranceClaim = 'InsuranceClaim',
  Other = 'Other',
}

export interface Job {
  // … existing fields …
  parentJobId?: number | null;
  comebackReason?: ComebackReason | null;
}
```

## Schema delta (consumer-side)

The lib ships an empty placeholder migration; consumers (TorqueTech) own
the actual schema delta via INFORMATION_SCHEMA-guarded idempotent SQL:

```sql
ALTER TABLE job ADD COLUMN parent_job_id INT NULL;
ALTER TABLE job ADD COLUMN comeback_reason VARCHAR(20) NULL;
ALTER TABLE job ADD CONSTRAINT fk_job_parent_job
    FOREIGN KEY (parent_job_id) REFERENCES job(job_id)
    ON DELETE SET NULL;
CREATE INDEX idx_parent_job_id ON job(parent_job_id);
```

## FK delete behaviour

- **Hard-delete** of a parent job (rare; sysadmin-only) cascades
  `parent_job_id → NULL` via the `ON DELETE SET NULL` clause. The child
  remains queryable; just no longer linked.
- **Soft-delete** (`deleted_at` set) is silently retained because of the
  lib's global query filter on `Job.DeletedAt`. The child's
  `parent_job_id` value persists in the column, but reads via the
  `ParentJob` nav property return `null` for soft-deleted parents.

## Cross-customer / cross-asset invariant

A comeback can only link to a parent that shares both `CustomerId` and
`AssetId`. Server-side guards in `JobComebackValidator` (TT-side) enforce
this; the typeahead picker filters client-side too.

Error codes (stable):

| Code | When |
|---|---|
| `invalid-comeback-reason` | Enum value missing or unknown |
| `comeback-self-link` | `parentJobId == jobId` (PATCH only) |
| `comeback-customer-mismatch` | Parent's customer differs |
| `comeback-asset-mismatch` | Parent's asset differs |
| `comeback-parent-not-found` | Parent missing in tenant scope |

## Multi-level chains

The data model permits comeback-of-comeback chains (`A.parentJobId = B.JobId; B.parentJobId = C.JobId`),
but the UI shows only the **immediate** parent on the chip and the
**direct** children in the reverse-direction badge. Chain traversal is
not exposed in v1.

## AutoCommentGenerator hook

`AutoCommentGenerator.TrackComebackLink(...)` returns the diff string
across five mutation shapes:

| Shape | Comment text |
|---|---|
| First link (null → set) | `"Linked as comeback for Job #J-1042 (Warranty) by Pat"` |
| Parent + reason change | `"Comeback parent changed from Job #J-1042 to Job #J-1058 (Warranty → Goodwill) by Pat"` |
| Parent change only | `"Comeback parent changed from Job #J-1042 to Job #J-1058 (Warranty) by Sam"` |
| Reason change only | `"Comeback reason changed from Warranty to Goodwill by Alex"` |
| Un-link (set → null) | `"Comeback link cleared (was Job #J-1042 / Warranty) by Jordan"` |

Pure diff function — caller persists via
`AutoCommentGenerator.AddComebackLinkComment(jobId, userId, systemId, commentText)`.

## Consumer guidance

For TorqueTech-style endpoints:

```csharp
// Edit-time PATCH
PATCH /api/jobs/{id}/comeback  { parentJobId, comebackReason }
// Both fields required; use DELETE for clear.

// Edit-time DELETE
DELETE /api/jobs/{id}/comeback
// No body. Idempotent on already-cleared.

// Create-time
POST /api/jobs  { …, parentJobId, comebackReason }
// Both optional; if either supplied, both must be.

// Picker (per-job and create-time variants)
GET /api/jobs/{id}/comeback-candidates?sinceDays=365&limit=20
GET /api/jobs/comeback-candidates?customerId=X&assetId=Y&sinceDays=365

// Reverse-direction lookup
GET /api/jobs?parentJobId=X
```

Server clamps `sinceDays` to `[1, 730]`; default 365 (matches typical
12-month workshop warranty terms). No tenant_setting for the lookback
in v1 (RFC 0028 § 12 Amendment 1 — 12c).

## Relationship to JobReopen

The future F15 comeback-rate report (RFC 0036) aggregates **two distinct
signals** to compute "rework rate":

1. **`Job.ParentJobId`** (this entity, v0.7.0) — explicit user-asserted
   comeback link captured at job creation or via PATCH. The customer
   physically brought the work back.
2. **TT-side `JobReopen` audit rows** (introduced in PR 19 per
   [RFC 0022 § 13](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md)) —
   admin reopened a Closed job back to InProgress without creating a
   new Job. The customer didn't physically bring it back; the workshop
   noticed and restarted.

PR 07 ships only signal 1. F15 unions both. F15 implementer must consume
**both** sources or the rework-rate metric will be biased.

`JobReopen` lives TT-side (table `job_reopen`) for v0.7.0; if a sister
product (MarineDeck etc.) adopts the reopen lifecycle, lift the entity
to `Chthonic.Work` v0.5.x or later.

## Non-goals

- **QC-template auto-inheritance** — comeback jobs do **not**
  auto-inherit the parent's QC view / checklist. Per
  [RFC 0028 § 13 Amendment 2 (13a)](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0028-comeback-linkage.md#13-amendment-2--scope-clarifications-2026-05-27),
  they use the standard QC pointer resolution chain established by
  PR 18 / RFC 0022 § 12 Amendment 1
  (`SystemRoleView.QcViewId` ?? `System.DefaultQcViewId` ?? …).
  The mechanic picks a different view manually if the comeback's scope
  differs from the original job. Auto-inheritance was rejected to avoid
  coupling `@chthonic/work` to `@chthonic/views` more tightly than
  current direction warrants.
- **Reverse-direction collection nav (`ChildComebacks`)** on `Job` —
  would force EF to materialize collections on every Job read. Reverse
  direction is opt-in via the consumer-side `?parentJobId=X` filter.
  Per [RFC 0028 § 13 Amendment 2 (13c)](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0028-comeback-linkage.md#13-amendment-2--scope-clarifications-2026-05-27).

## Tests

- `JobComebackHelpersTests` — `ComebackReasonToString` / `…FromString` round-trip + invalid input throws (14 cases).
- `JobConfigurationComebackTests` — EF model: column mappings, HasConversion wiring, self-FK with `OnDelete SetNull` + correct constraint name, `idx_parent_job_id` index (5 cases).
- `JobEntityShapeTests` (extended) — property presence, nullability, enum count + ordinal values (6 new cases).
- `AutoCommentGeneratorComebackTests` — 5 mutation shapes + 2 no-change variants + persistence wiring (10 cases).

## Downstream: TorqueTech comeback-rate report (RFC 0036)

`Job.ParentJobId` is the **data source** for TorqueTech's F15 comeback-rate report (a TT-only, Premium-gated read-only report — no change to `@chthonic/work`). The report aggregates parent/child `Job` links into a monthly comeback rate.

**Comeback rate is measured per completed PARENT job.** A parent job (one with a `CompletedAt` in the reporting period) counts as a comeback if it has **≥1 child job** (`ParentJobId` pointing back) **created within a `windowDays` window of its completion** — `windowDays` is 30 / 60 / 90 (default 30). Numerator = such parents; denominator = parent jobs completed in the period (a job must have had the chance to come back).

- **Reporting period vs window are distinct axes** — `from`/`to` select parents by `CompletedAt`; `windowDays` bounds how long after close a return still counts (keeps the denominator stable as the window widens).
- **Raw rate vs quality rate** — the raw rate counts every `ComebackReason`; an `excludeReasons` filter (e.g. `Goodwill`) yields the "quality rate". A child with a **null** reason is always counted and never excluded.
- **Breakdown attributes to the parent** job's assigned mechanic / service type (the original work whose quality is in question).

> **Note on the second signal.** As documented under [Relationship to JobReopen](#relationship-to-jobreopen), the metric can also union TT-side `JobReopen` audit rows. The v1 F15 report (PR 15) aggregates the explicit `Job.ParentJobId` linkage; a `JobReopen` union remains a documented follow-up. See RFC 0036 § 12 Amendment 1.

## Cross-references

- [RFC 0028 — Comeback / warranty-job linkage](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0028-comeback-linkage.md) — Accepted 2026-05-27 with § 12 Amendment 1 (12a-d) + § 13 Amendment 2 (13a-c)
- [RFC 0036 — Comeback-rate report (F15)](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0036-comeback-rate-report.md) — consumer (Accepted 2026-07-21 § 12 Amendment 1; shipped PR 15)
- [RFC 0022 § 13 — F1c/F1d state-machine simplification](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md) — the source of `JobReopen`, the second signal F15 unions with this one
- [PR 06 — F6 Job priority](priority.md) — sibling pattern (additive column on `Job` instead of Custom Field)
- [`@chthonic/work` v0.7.0 release](https://github.com/chthonicsystems/work/releases/tag/v0.7.0)
