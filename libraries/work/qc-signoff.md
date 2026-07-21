---
library: work
related-rfcs: [0022, 0035]
last-verified: 2026-07-21
tags: [work, qc-signoff, rework, state-machine]
summary: QC sign-off & rework round-trip — per-attempt audit + auto-derive Passes from FieldBoundsValidator + rework loop integration with JobStatus state machine. v0.2.0+. (v0.4.0 — three-status lifecycle. v0.5.0 — per-result upsert in SaveDraft / SubmitSignoff.) Data source for TorqueTech's first-time-pass QC report (F14, RFC 0035).
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

## Save and submit semantics (v0.5.0+)

`SaveDraftAsync` and `SubmitSignoffAsync` are **per-result upserts** keyed on `(QcSignoffId, EntityFieldId)`. Existing rows for fields not present in the request payload are **preserved**.

Previously (v0.4.x and earlier), both methods deleted the entire `QcSignoffItemResult` set on the signoff and rewrote it from the payload. This caused data loss when callers sent a partial payload — e.g. TorqueTech's JobDetail Sign Off button collects only inline-screen renderer values via `collectQcPayload`, so submitting a job whose QC view has only non-inline screens (Brake Service auto-synth) sent an empty payload and wiped the supervisor's saved draft.

The v0.5.0 semantics match the operational `JobFieldValue` per-`(Entity, Name)` upsert pattern:

| Existing → New (per result) | Action |
|---|---|
| (no row) → fail | INSERT result + INSERT QcRework (when `writeRework=true`) |
| pass → fail | UPDATE result + INSERT QcRework if none exists |
| fail → pass | UPDATE result + DELETE existing QcRework |
| fail → fail | UPDATE notes/value, leave QcRework intact |
| (no row) → pass | INSERT result only |
| pass → pass | UPDATE value/notes only |
| not in payload, currently failing | leave alone, but at submit time backfill QcRework if missing (preserves the "every failure has a rework" invariant) |

`SubmitSignoffAsync.anyFailed` derives from the **post-upsert union** of all results on the signoff — existing untouched rows + payload upserts. A submit with empty payload correctly reflects the existing draft's pass/fail state; a submit with a partial payload reflects union state.

Auto-comment line items count the full post-upsert result set ("`{N} items checked`"), not the payload size, so the comment reflects the supervisor's actual review surface.

API surface unchanged from v0.4.x. Consumers sending full payloads see no behaviour change. Consumers sending partial / empty payloads now correctly preserve the rest of the draft.

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

## Downstream: TorqueTech first-time-pass QC report (RFC 0035)

`QcSignoff` is the **data source** for TorqueTech's F14 first-time-pass QC rate report (a TT-only, Premium-gated read-only report — no change to `@chthonic/work`). The report aggregates `QcSignoff` rows into a monthly first-time-pass rate.

**First-time-pass is measured per JOB** (not per signoff): a job is first-time-pass if it has a `Passed` `QcSignoff` **and zero `Reworked` attempts** in its history. Because a Job can have **multiple QcSignoff rows** (one per rework-loop attempt — see [Entities](#entities)), the presence of any `Reworked` attempt disqualifies the job even if a later attempt `Passed`. The denominator is jobs that reached a terminal QC state (`Passed` or `Reworked`) in the period.

> This refines RFC 0035 § 2's original per-signoff phrasing ("a `Passed` signoff with zero linked `QcRework` rows") — a `Passed` attempt inherently has no `QcRework`, so the per-job history is what captures first-time-ness. See RFC 0035 § 12 Amendment 1.

## Refs

- RFC 0022 — Quality Control sign-off & rework round-trip (Accepted 2026-05-23). Full design including the 8-alternative refinement journey in § 10.
- RFC 0035 § 12 Amendment 1 — F14 First-time-pass QC rate report (Accepted 2026-07-20). Consumes `QcSignoff` per-job history for the first-time-pass rate; TT-only, Premium-gated. TorqueTech `feat/14-F14-first-time-pass-report` PR #321.
- RFC 0024 § 12 Amendment 1 — F3 Photo + Video QC Evidence (PR 05). The work lib stays evidence-agnostic: `QcItemResult.FileIds` plumbing slot is consumed by TT-side `QcSignoffOrchestrator.BindFilesToResultsAsync`, which tags file rows via `@chthonicsystems/files` v0.2.0's two-level polymorphic FK (`sub_entity_type='QcSignoffItem'`). For the full TT consumer pattern see [`../files/qc-evidence.md`](../files/qc-evidence.md).
- `@chthonic/views` v0.6.0 — provides `View.Kind` discriminator, `EntityField.MinValue/MaxValue/Unit/ParentFieldId`, `FieldBoundsValidator` utility (consumed by `QcSignoffService.SubmitSignoffAsync`). For the F2 product surface (operational + QC dual-mode tolerance display, lifted `<NumericField>` hint, RFC 0023 architectural divergence record) see [`../views/tolerance-bounds.md`](../views/tolerance-bounds.md).
- `@chthonic/views` v0.8.13 — `renderQcAttachmentSlot` prop on `<ScreenSectionsRenderer>`; PR 05 wiring point for evidence slots. See [`../views/screen-sections-renderer.md`](../views/screen-sections-renderer.md).
- `@chthonicsystems/mobile-runtime` v0.3.0 — `useMediaCapture` (photo + video). See [`../mobile-runtime/media-capture.md`](../mobile-runtime/media-capture.md).
- TorqueTech `feat/01-F1-qc-signoff` PR — primary consumer.
