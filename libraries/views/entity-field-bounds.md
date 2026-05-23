---
library: views
related-rfcs: [0022]
last-verified: 2026-05-23
tags: [views, bounds, validation, qc]
summary: Numeric bounds metadata on EntityField (MinValue/MaxValue/Unit) — dual-purpose save-time / result-time semantics with FieldBoundsValidator.
---

# Numeric bounds on `EntityField`

`@chthonic/views` v0.6.0 adds three columns to `EntityField` for generic numeric bounds + validation:

| Column | Purpose |
|---|---|
| `MinValue` (decimal?) | Lower bound (inclusive). Null = no lower bound. |
| `MaxValue` (decimal?) | Upper bound (inclusive). Null = no upper bound. |
| `Unit` (string?, max 20) | Unit suffix for display + reason strings (e.g. `"mm"`, `"PSI"`). |

These columns are **generic**, not QC-specific. Operational fields (mileage, tyre pressure, engine hours) benefit from save-time bounds enforcement; QC fields (pad thickness, brake fluid colour, charge rate) consume the same metadata for result-time pass/fail derivation.

## Dual-purpose semantics — same metadata, two write paths

The interpretation of bounds depends on the storage path the value flows through, which is keyed off the parent View's `Kind`:

| View kind | Storage path | Bounds semantics |
|---|---|---|
| `operational` | `EntityFieldValue` | Save-time enforcement: out-of-bounds → 400 with structured error. |
| `qc` | `QcSignoffItemResult` | Result-time derivation: out-of-bounds value is stored with `Passes=false`; auto-rework row created with structured reason. |

This keeps the data model clean — one set of columns, two interpretation rules — without polluting EntityField with QC-specific concepts.

## `FieldBoundsValidator` — the shared utility

Single source of bounds-check semantics across the platform. Both write paths consume it:

```csharp
namespace Chthonic.Views.Validation;

public static class FieldBoundsValidator
{
    public static readonly IReadOnlySet<string> QcEligibleTypes;     // boolean, boolean-attachment, number, number-attachment, empty
    public static readonly IReadOnlySet<string> NumericTypes;        // number, number-attachment

    public static (bool inBounds, string? reason) Check(
        decimal value, decimal? min, decimal? max, string? unit);
}
```

- **`(true, null)`** — value is in range (inclusive) or no bounds set
- **`(false, "Below minimum 2.0mm")`** — value < min
- **`(false, "Above maximum 10.0mm")`** — value > max

The reason string is human-readable and suitable for both 400-error responses and QC rework reasons.

## `SaveValidation` — save-time helpers

Validation that runs before `SaveChangesAsync`:

```csharp
SaveValidation.ValidateField(field);                                         // bounds-on-numeric-only; min ≤ max
SaveValidation.ValidateParent(field, parent);                                // no chains
SaveValidation.ValidateView(view, baseFields);                               // QC view base fields type-eligibility
await SaveValidation.ValidateNoChainsAsync(field, dbContext, ct);            // async parent lookup
```

Throws `ArgumentException` on violation; consumers catch and translate to 400 / `ValidationError`.

## Type eligibility table

| Type | Bounds allowed? | Renderable in operational view? | Renderable in QC view? |
|---|---|---|---|
| `text` | ❌ | ✅ | ❌ (skipped) |
| `number` | ✅ | ✅ | ✅ |
| `date` / `datetime` | ❌ | ✅ | ❌ (skipped) |
| `boolean` | ❌ | ✅ | ✅ |
| `options` | ❌ | ✅ | ❌ (skipped) |
| `checkbox` | ❌ | ✅ | ❌ (skipped) |
| `boolean-attachment` (NEW v0.6.0) | ❌ | ✅ (toggle + photo) | ✅ |
| `number-attachment` (NEW v0.6.0) | ✅ | ✅ (input + photo) | ✅ |
| `empty` (NEW v0.6.0) | ❌ | (renders nothing) | ✅ when has children (anchor only) |

QC view base-fields are validated at save: types not in `{boolean, boolean-attachment, number, number-attachment, empty}` are rejected with `ArgumentException`.

## Consumers

- **Operational write path** (TorqueTech `JobFieldService.PrepareFieldUpdate`): runs `FieldBoundsValidator.Check` on numeric values before `db.JobFieldValues.Add`. Out-of-bounds → returns validation error → endpoint translates to 400.
- **QC submit path** (`Chthonic.Work.Services.QcSignoffService.SubmitSignoffAsync` v0.2.0+): runs `FieldBoundsValidator.Check` on numeric values; stores raw value with derived `Passes`; auto-creates `QcRework` row with the `reason` string on failure.
- **Field editor UI** (`SectionFields` in TorqueTech): exposes Min / Max / Unit inputs when the user picks a numeric type. Validation surfaces inline as the admin types.

## v0.8.0 — `ExcludeFromQc` per-field opt-out (PR 18 / RFC 0022 § 12)

A peer companion to the bounds metadata: `EntityField.ExcludeFromQc` (`bool`, default `false`) is a per-field flag that drops a field (and its children, if any) from the QC eligibility tree even when its `Type` would otherwise qualify.

**Read only on top-level fields** (`ParentFieldId IS NULL`). Setting it on a child row is a no-op (UI hides the toggle on child rows; dead `true` data on a child is harmless because the eligibility tree only consults it on top-level fields).

The 3-step eligibility decision tree applied per top-level field:

```
1. field.ExcludeFromQc = true         → DROP subtree entirely
2. Has direct children                 → use children, filtered to QcEligibleTypes
3. No children                         → keep self if Type ∈ QcEligibleTypes AND Type ≠ "empty"
```

| Set on | Effect |
|---|---|
| Top-level **leaf** (no children) | Drops the field |
| Top-level **parent** (has children) | Drops the parent AND all its children (subtree-level) |
| **Child** field | Irrelevant — never read |

Consumer responsibility: the eligibility tree lives in `Chthonic.Work` / `JobFieldsViewService.AppendVirtualServiceScreensInternal` (TT-side) — `@chthonic/views` exposes the column + the `QcEligibleTypes` constant, but doesn't enforce eligibility itself (consumers compose).

## Refs

- RFC 0022 § 2 (Decision) — view-with-kind hybrid + bounds-on-EntityField rationale
- RFC 0022 § 12 Amendment 1 — `ExcludeFromQc` rationale + 3-step eligibility decision tree
- RFC 0023 — F2 Tolerance validation (consumer; no further schema bumps needed because v0.6.0 already shipped the columns)
- RFC 0024 — F3 Photo-evidence-required QC items (consumer; uses the `*-attachment` types)
- `@chthonic/work` v0.2.0 — `QcSignoffService.SubmitSignoffAsync` is the canonical QC consumer of `FieldBoundsValidator`
