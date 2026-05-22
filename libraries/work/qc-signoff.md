---
library: work
related-rfcs: [0022]
last-verified: 2026-05-23
tags: [work, qc-signoff, rework, state-machine]
summary: QC sign-off & rework round-trip — per-attempt audit + auto-derive Passes from FieldBoundsValidator + rework loop integration with JobStatus state machine. v0.2.0+.
---

# QC sign-off & rework round-trip

`@chthonic/work` v0.2.0 adds the QC sign-off vocabulary on top of the existing Job spine. Three new entities, one new extension hook, one new service interface, plus a JobStatus enum extension.

## State machine extension

Existing 3-state graph (`InProgress → Completed → Closed` with reverts) extends additively:

```
InProgress → Completed → PendingQcSignoff
                              ├─ all-pass → QcPassed → Closed
                              └─ any-fail → Reworked → InProgress → Completed → re-loop
```

Five new transitions added to `JobStatusTransitions.IsValid`:

| From | To | Trigger |
|---|---|---|
| `Completed` | `PendingQcSignoff` | `IQcSignoffService.StartSignoffAsync` |
| `PendingQcSignoff` | `QcPassed` | `IQcSignoffService.SubmitSignoffAsync` (all pass) |
| `PendingQcSignoff` | `Reworked` | `IQcSignoffService.SubmitSignoffAsync` (any fail) |
| `QcPassed` | `Closed` | normal close path |
| `Reworked` | `InProgress` | mechanic resumes |

The new transitions are gated by the new `IJobStatusTransitionValidator` extension hook so existing tenants without a `kind=qc` SystemView see zero behaviour change.

## Entities

```
QcSignoff (per-attempt audit row)
├── QcSignoffId
├── JobId          ─→ Job
├── ViewId         ─→ SystemView (kind=qc)
├── SignedByUserId ─→ User
├── SignedAt
└── Status         ∈ {InProgress, PendingSignoff, Reworked, Passed}

QcSignoffItemResult (per-item value + derived Passes)
├── QcSignoffItemResultId
├── QcSignoffId    ─→ QcSignoff (CASCADE)
├── EntityFieldId  ─→ EntityField (in @chthonic/views)
├── Value          (raw — "true"/"false" for booleans; numeric string for numbers)
├── Passes         (derived at submit time)
└── Notes

QcRework (failure resolution; unique on item_result_id)
├── QcReworkId
├── QcSignoffItemResultId ─→ QcSignoffItemResult (CASCADE)
├── Reason
├── ResolvedAt
└── ResolvedByUserId ─→ User
```

A Job can have **multiple QcSignoff rows** over its lifetime — one per attempt in the rework loop. Each attempt's results are first-class auditable rows.

## Public surface

```csharp
namespace Chthonic.Work.Services;

public interface IQcSignoffService
{
    Task<QcSignoff> StartSignoffAsync(int jobId, int viewId, int userId, CancellationToken ct = default);
    Task<QcSignoff> SubmitSignoffAsync(int signoffId, IEnumerable<QcItemResult> results, CancellationToken ct = default);
    Task<QcRework> CreateReworkAsync(int qcSignoffItemResultId, string reason, int userId, CancellationToken ct = default);
}

public record QcItemResult(
    int EntityFieldId,
    string Value,
    string? Notes = null,
    IReadOnlyList<int>? FileIds = null);

namespace Chthonic.Work.Extensions;

/// <summary>NEW in v0.2.0 — per-tenant transition gate.</summary>
public interface IJobStatusTransitionValidator
{
    Task<bool> CanTransitionAsync(Job job, JobStatus newStatus, CancellationToken ct = default);
}
```

## How `Passes` is derived

`SubmitSignoffAsync` walks the input `QcItemResult` rows and computes `Passes` per-item:

| EntityField.Type | Logic |
|---|---|
| `boolean` / `boolean-attachment` | `bool.Parse(value)` — `true` → `Passes=true`; `false` or unparseable → `Passes=false` |
| `number` / `number-attachment` | `Chthonic.Views.Validation.FieldBoundsValidator.Check(value, MinValue, MaxValue, Unit)` — out-of-bounds → `Passes=false` |
| `empty` | Always passes (anchor row only — no actual value) |
| Other types | Throws — QC views must have type-validated base fields |

For each failed item, the service:

1. Persists the `QcSignoffItemResult` with `Passes=false` and the raw `Value`
2. Auto-creates a `QcRework` row with the `Reason` from `FieldBoundsValidator` (numeric) or a templated string (boolean)
3. Sets `QcSignoff.Status = Reworked`
4. Transitions Job → `JobStatus.Reworked` via `IJobService.UpdateStatusAsync`

If all items pass, the service transitions Job → `JobStatus.QcPassed`.

## Idempotent on double-submit

If the QcSignoff is already in a terminal state (`Passed` or `Reworked`), `SubmitSignoffAsync` returns the existing row unchanged. Mobile callers retrying after a flaky network won't double-submit.

## `IJobStatusTransitionValidator` — the new gate hook

`@chthonic/work` v0.1.0 had `IJobStatusValidator` (forward field-required check) and `IJobStatusChangedHandler` (post-commit notification dispatch). Neither gates *which* transitions are legal per-tenant — `JobStatusTransitions.IsValid` is a pure structural matrix.

The new hook lets consumers (e.g. TorqueTech) reject transitions even when they're structurally legal — for example, rejecting `Completed → PendingQcSignoff` when the tenant doesn't have JobsQc enabled or doesn't have a `kind=qc` SystemView configured.

The hook is **optional** — if no implementation is registered, all structurally-legal transitions are permitted (preserves v0.1.0 behaviour).

```csharp
// Consumer-side adapter (TorqueTech)
public sealed class TTJobStatusTransitionValidator : IJobStatusTransitionValidator
{
    public async Task<bool> CanTransitionAsync(Job job, JobStatus newStatus, CancellationToken ct = default)
    {
        if (newStatus != JobStatus.PendingQcSignoff) return true;       // only gate QC entry
        var enabled = await _gate.IsEnabledAsync("JobsQc", ctx, ct);
        if (!enabled) return false;
        return await _db.SystemViews.AnyAsync(v => v.SystemId == job.SystemId && v.Kind == "qc", ct);
    }
}
```

## Refs

- RFC 0022 — Quality Control sign-off & rework round-trip (Accepted 2026-05-23). Full design including the 8-alternative refinement journey in § 10.
- `@chthonic/views` v0.6.0 — provides `View.Kind` discriminator, `EntityField.MinValue/MaxValue/Unit/ParentFieldId`, `FieldBoundsValidator` utility (consumed by `QcSignoffService.SubmitSignoffAsync`).
- TorqueTech `feat/01-F1-qc-signoff` PR — primary consumer.
