---
library: views
related-rfcs: [0022, 0023]
last-verified: 2026-05-25
tags: [views, tolerance, bounds, validation, qc, f2]
summary: F2 tolerance validation product surface — lifted <NumericField> tolerance hint shows in operational + QC modes via one selector. v0.8.12.
---

# Tolerance bounds — F2 product surface

`@chthonic/views` v0.8.12 (PR 04 / RFC 0023 Amendment 1) lifts the on-screen "Tolerance: min – max unit" hint into `<NumericField>` itself, so both **operational-mode entry** and **QC-mode submit** display the hint via the same component path. This page documents the F2 capability end-to-end as a product surface (entity → editor → renderer → validator); for the underlying bounds metadata + validator details see [`entity-field-bounds.md`](entity-field-bounds.md).

## Selector contract

```
data-testid="tolerance-hint-${field.systemJobFieldId}"
```

This selector is identical in operational and QC editable modes. Playwright + downstream consumers can use one selector regardless of view kind.

CSS class: `.numeric-field-tolerance-hint` (renamed in v0.8.12 from `.qc-tolerance-hint`).

## Where the hint renders

| View kind | Editable | Component path | Hint visible? |
|---|---|---|---|
| operational | yes | `<NumericField>` | ✅ |
| operational | readonly | `<ReadOnlyField>` | ❌ (read-only path doesn't carry the hint) |
| qc | yes | `<NumericField>` (lifted) | ✅ |
| qc | readonly | `<ReadOnlyField>` (with inline render kept in `<ScreenSectionsRenderer>` for parity) | ✅ |

In QC editable mode, `<ScreenSectionsRenderer>`'s QC-numeric branch wraps `<NumericField>` so the hint comes from the field component. In QC readonly mode, `<ReadOnlyField>` is used (which doesn't render the hint), so the renderer keeps an inline render with the same `tolerance-hint-${id}` selector to preserve the QC history view.

## End-to-end data flow

```
Admin
  ↓ FieldsManager / FieldEditModal (views v0.7.0)
  ↓ POST/PUT /api/custom-fields/fields { minValue, maxValue, unit }
  ↓ SaveValidation.ValidateField — bounds-on-numeric-only + min ≤ max
EntityField table (in @chthonic/views)
  ↓ JobFieldsViewService projection — populates JobFieldItemDto
JobFieldItemDto { minValue, maxValue, unit, parentFieldId, excludeFromQc, ... }
  ↓ JSON over wire
JobField (npm, in @chthonicsystems/views)
  ↓ <ScreenSectionsRenderer> dispatch on (Type, kind)
<NumericField> with field.minValue / field.maxValue / field.unit
  ↓ render
<div class="numeric-field-tolerance-hint" data-testid="tolerance-hint-${id}">
  Tolerance: 3 – 10mm
</div>
```

## Validation in the two write paths

The **same** static `Chthonic.Views.Validation.FieldBoundsValidator.Check(value, min, max, unit)` is invoked at:

1. **Operational save** — `JobFieldService.ValidateNumericBounds` (TT api side) rejects out-of-range values at write-time with HTTP 400 + the bounds reason.
2. **QC submit** — `IQcSignoffService.SubmitSignoffAsync` (work lib v0.2.0+) auto-derives `Passes` per-item; out-of-range items are stored with `Passes=false` and trigger an auto-`QcRework` row with the bounds reason.

This dual-path consumption is what motivated putting bounds on `EntityField` (in views) rather than on a `QcItem` entity (in work) — see [RFC 0023 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0023-tolerance-validation.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26).

## Hint label format

| `minValue` | `maxValue` | `unit` | Renders |
|---|---|---|---|
| 3 | 10 | "mm" | `Tolerance: 3 – 10mm` |
| 3 | null | "mm" | `Tolerance: 3 – ∞mm` |
| null | 50 | "psi" | `Tolerance: ∞ – 50psi` |
| null | null | (any) | (no hint rendered) |
| 1 | 5 | null | `Tolerance: 1 – 5` |

The `∞` glyph signals no bound; the unit suffix is appended when present (no space).

## Interaction with QC-mode result pill

When QC submit returns and the renderer is in readonly mode, the tolerance hint and the result pill (`✓ Pass` or `✗ Fail — Below minimum 3.0mm`) both render in the same `qc-field--numeric` wrapper. The hint is purely informational; the failure reason in the pill is the canonical signal.

## No tier gating

Tolerance bounds are **intrinsic to the field** — if `minValue` or `maxValue` is set, validation runs everywhere a value is entered. There is no `FeatureFlag.JobsQcTolerance` gate. The originally-proposed flag was dropped during PR 04; tier-gating QC sign-off itself (the F1 envelope) is sufficient for paid-tier separation.

## TT-side projection delta (PR 04)

Pre-PR-04, TT's `JobFieldItemDto` did **not** project `MinValue` / `MaxValue` / `Unit` from `EntityField`. The renderer never saw the bounds and the hint stayed hidden in operational mode (and would have stayed hidden in QC mode too — the views unit tests had been passing because they pass `JobField` objects directly with bounds set; no integration test had exercised the end-to-end DTO chain).

PR 04 extends the DTO with `MinValue`, `MaxValue`, `Unit`, `ParentFieldId`, `ExcludeFromQc` and projects them at all 4 sites in `JobFieldsViewService` — orphan-fields section, auto-synth screens, main view projection, QC-mode child expansion.

Sister products that consume `@chthonic/views` directly should mirror this projection in their own DTO when extending the views' minimal field DTO with consumer-specific columns.

## Refs

- [`entity-field-bounds.md`](entity-field-bounds.md) — the bounds metadata + `FieldBoundsValidator` semantics.
- [`screen-sections-renderer.md`](screen-sections-renderer.md) — `<ScreenSectionsRenderer>` dispatch matrix.
- [`qc-resolution.md`](qc-resolution.md) — view-kind discriminator + QC eligibility tree.
- [RFC 0023](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0023-tolerance-validation.md) — F2 design.
- [RFC 0023 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0023-tolerance-validation.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26) — Records what actually shipped vs the original RFC.
- [`@chthonicsystems/views` v0.8.12 release](https://github.com/chthonicsystems/views/releases/tag/v0.8.12).
- [`libraries/work/qc-signoff.md`](../work/qc-signoff.md) — sibling: QC submit consumes the same bounds for `Passes` derivation.
