---
library: views
package-nuget: Chthonic.Views
package-npm: '@chthonicsystems/views'
version: 0.8.12
related-rfcs: [0010, 0022, 0023]
related-libs: [tenant, audit, catalog]
last-verified: 2026-05-25
tags: [cross-cutting, custom-fields, views, screens, qc, tolerance]
summary: Custom field definitions + per-role view configurations + ScreenSectionsRenderer + v0.6.0 view-kind discriminator + numeric bounds + parent-child structure for QC + v0.8.12 lifted operational-mode tolerance hint.
---

# `@chthonicsystems/views` / `Chthonic.Views`

Per-tenant custom fields + per-role/per-status view configurations. Powers the dynamic field/screen rendering for jobs (and any other consumer entity).

## Purpose

Tenants need to customise data-collection per workflow. A motorbike service centre wants different fields on a job than a marina. RBAC needs different field visibility per role. The platform needs this without forking schema per tenant.

`@chthonic/views` provides:

- `Service Screens` (named screens) and `Sections` (screen subdivisions).
- Custom fields per entity type (Job, Customer, Vehicle, Vessel, Pet, ...).
- Field types: text, numeric, date, checkbox, options, combo, multivalue.
- Visibility rules by role + by entity status.
- `<ScreenSectionsRenderer>` — renders all visible fields for an entity in correctly-grouped sections.
- View resolution: User Role → Role Override → System Default → Fallback.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IViewResolver` | Resolves the active view for a (user, entity-type) tuple |
| `IEntityFieldService` | Read/write field values |
| `ISystemViewService` | View CRUD |
| `ICustomFieldsService` | Field definition CRUD |
| `IFieldOptionsService` | Dropdown option CRUD |
| `ISystemEntityFieldUpdateService` | Atomic replace of a view's full field configuration |
| `MapChthonicViewsEndpoints` | `/api/system-views/*`, `/api/system-entity-fields/*`, `/api/settings/*` |
| `services.AddChthonicViews()` | DI entry point |

**Domain entities (12):** `SystemView`, `SystemRoleView`, `SystemEntityFieldCategory`, `SystemEntityFieldSubCategory`, `SystemEntityField`, `SystemEntityFieldOption`, `SystemEntityFieldRole`, `SystemEntityFieldStatus`, `EntityFieldValue`, plus 3 extension entity classes.

### npm

| Export | Role |
|---|---|
| `<ScreenSectionsRenderer>` | Dynamic field renderer for an entity |
| `<FieldRenderer>` | Single-field renderer |
| Dynamic field components | `TextField`, `NumericField`, `DateField`, `CheckboxField`, `OptionsField`, `ComboField`, `MultiValueOptionsField`, etc. |
| `useResolvedView({ entityType, entityId })` | Hook returning the active view |
| `useEntityFieldValues({ entityType, entityId })` | Hook returning current field values |

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id scoping |
| `@chthonic/audit` | View / field change audit |
| `@chthonic/catalog` (optional) | Field linkage to ServiceItem.Cost / Product |

## Extension points

| Hook | Use |
|---|---|
| `IAutoScreenProvider<TEntity>` | Per-entity-type auto-section provider |
| `IAutoOptionsProvider` | Per-field auto-options (e.g. mechanics from users table) |
| `IDbContextProvider` (port) | Bridge to consumer DbContext |
| `setHttpAdapter(httpService)` (npm) | Bridge to consumer HTTP layer |

## Consuming this library

```csharp
builder.Services.AddScoped<IDbContextProvider, MyDbContextProvider>();
builder.Services.AddScoped<IAutoScreenProvider<Job>, JobAutoScreenProvider>();
builder.Services.AddScoped<IAutoOptionsProvider, MyAutoOptionsProvider>();
builder.Services.AddChthonicViews();
app.MapChthonicViewsEndpoints();
```

```tsx
import { setHttpAdapter, ScreenSectionsRenderer } from '@chthonicsystems/views';
setHttpAdapter(httpService);

<ScreenSectionsRenderer entityType="Job" entityId={jobId} systemId={systemId} userId={userId} />
```

## v0.6.0 — QC view kind (PR 01 / RFC 0022)

| Schema delta | Notes |
|---|---|
| `View.Kind` (`varchar(20)`, default `"operational"`) | Discriminator. `"operational"` (default) or `"qc"`. F1b deprecates this on top-level views (`ServiceId IS NULL`) but keeps it for service-scoped views. |
| `EntityField.MinValue` / `MaxValue` (`decimal(18,6)?`) + `Unit` (`varchar(20)?`) | Generic numeric bounds. Operational save-time validation; QC submit-time `Passes` derivation via `FieldBoundsValidator`. |
| `EntityField.ParentFieldId` (`int?`, self-FK with `ON DELETE CASCADE`) | One-level only — children replace parent in QC views. |
| Type set extends with `boolean-attachment`, `number-attachment`, `empty` | New widget shapes for QC checks. |

`FieldBoundsValidator` (static helper) + `QcEligibleTypes` constant. Save-time validation in `IViewService.SaveAsync` and `IEntityFieldService.SaveAsync`.

## v0.8.0 — QC defaults & opt-out (PR 18 / RFC 0022 § 12 Amendment 1)

Refines F1's view-selection model after production learnings.

| Schema delta | Notes |
|---|---|
| `SystemRoleView.QcViewId` (`int?` FK to `system_view`, `ON DELETE RESTRICT`) | Per-role QC view override. Mirrors `DefaultViewId` / `QuickViewId` / `JobCardViewId`. New pointers get RESTRICT (decision A=2 — old pointers keep `SET NULL`). |
| `EntityField.ExcludeFromQc` (`bool`, default `false`) | Per-field opt-out. Read only on top-level fields by the eligibility tree. UI hides the toggle on child rows. |

`ScreenSectionsRenderer` gains a `kind?: 'operational' | 'qc'` prop with a `(Type, kind)` widget dispatch matrix:

- `boolean` / `boolean-attachment` × `qc` → `CheckboxField` + optional photo slot
- `number` / `number-attachment` × `qc` → `NumericField` + tolerance display + optional photo slot
- non-QC-eligible × `qc` → dropped (defensive — server-side eligibility tree should already have stripped these)

Top-level views are kind-neutral — any view can render in either kind. Eligibility tree (in consumer-side `JobFieldsViewService`):

```
1. field.ExcludeFromQc = true → DROP subtree
2. Has direct children → use children, filtered to QcEligibleTypes
3. No children → keep self if Type ∈ QcEligibleTypes AND Type ≠ "empty"
```

### Patch releases (UX polish from production usage)

- **v0.8.1** — `FieldEditModal` copy: "QC parent (optional)" → "Part of a QC group (optional)"; "Empty (anchor for QC checks)" → "Group (no value — organises QC checks)"; helper text rewritten in plain English.
- **v0.8.2** — Drop "Only one level of grouping is allowed" from picker hint (the constraint is enforced anyway by `parentCandidates` filtering).
- **v0.8.3** — `FieldsManager` shows QC group children inline as click-to-edit chips under each parent row. `parentFieldId` exposed on `FieldData` type.
- **v0.8.4** — Expand `QC` to `Quality Control` in user-facing copy (modal labels, hint text). Internal types / class names keep the abbreviation.
- **v0.8.5** — `QcNoteButton` + per-field note storage. Hides quantity/amount fields in QC kind dispatch.
- **v0.8.6** — `deriveAllPassing` client-side util — given fields + values, returns `{ allPassing: bool, failingCount: number }`. Lets consumers split the supervisor button (Sign Off when `allPassing`, Send for Rework otherwise) without re-implementing the logic.
- **v0.8.7** — `ReadOnlyField` always renders the label, no hide-when-empty. Read-only QC view used to render an empty `<div>` when a field had no value, breaking row alignment in the renderer.
- **v0.8.8** — `getFieldValues()` becomes QC-aware. Was filtering by operational `isFieldEditable(jobStatus)` returning `false` for non-`InProgress`, dropping all values for the supervisor's QC view. Now uses type-based eligibility for the QC kind.
- **v0.8.9** — `QcNoteModal` restyle. Drops the explanation paragraph, adopts `app-modal-header` / `app-modal-body` shell, adds Escape-to-close.
- **v0.8.10** — QC dispatch honours `readonly` prop. Was always emitting `CheckboxField` / `NumericField`; now routes to `ReadOnlyField` when `readonly=true` so a viewer-side render of a closed-out QC sign-off doesn't accidentally surface editable controls.
- **v0.8.11** — Read-only QC hides the note chip when the item failed. The `failReason` rendered inside the result pill already surfaces the supervisor's text; rendering it twice (chip + reason) looked like a duplicate. Passing items with notes still show the chip.

See [RFC 0022 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md#12-amendment-1--f1b-qc-view-defaults--opt-out-2026-05-24) for the full design rationale. v0.8.4 through v0.8.11 are UX polish patches landed during the F1c/F1d work tracked in [RFC 0022 § 13 Amendment 2](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md#13-amendment-2--f1cf1d-state-machine-simplification--reopen-tracking--rework-badge-2026-05-24).

## v0.8.12 — Operational-mode tolerance hint via lifted `<NumericField>` (PR 04 / RFC 0023 Amendment 1)

Lifts the on-screen "Tolerance: min – max unit" hint from `<ScreenSectionsRenderer>`'s QC-mode branch into `<NumericField>` itself. Both operational-mode entry and QC-mode submit display the hint via the same component path. Selector contract: `data-testid="tolerance-hint-${field.systemJobFieldId}"` applies in BOTH modes.

| Change | Impact |
|---|---|
| `<NumericField>` renders tolerance hint when `field.minValue` or `field.maxValue` is set | Operational entry now shows the expected range inline (was QC-mode only) |
| `<ScreenSectionsRenderer>` QC-numeric editable branch removes its own hint render | DRY — one component path |
| `<ScreenSectionsRenderer>` QC-numeric readonly branch keeps inline render | `<ReadOnlyField>` doesn't carry the hint; preserves QC history view parity |
| CSS class rename: `.qc-tolerance-hint` → `.numeric-field-tolerance-hint` | Same visual styling; reflects the new dual-mode home |

Additive; API surface unchanged. See [`tolerance-bounds.md`](tolerance-bounds.md) for the F2 product surface end-to-end and [RFC 0023 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0023-tolerance-validation.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26) for the architectural divergence record.

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`custom-fields.md`](custom-fields.md), [`entity-field-discriminator.md`](entity-field-discriminator.md), [`entity-field-bounds.md`](entity-field-bounds.md), [`tolerance-bounds.md`](tolerance-bounds.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`auto-providers.md`](auto-providers.md).
- Library repo: [chthonicsystems/views](https://github.com/chthonicsystems/views).
- [RFC 0010](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0010-views-and-custom-fields.md).
- [RFC 0022](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md) — QC sign-off, including § 12 Amendment 1 for v0.8.x changes.
- [RFC 0023](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0023-tolerance-validation.md) — F2 tolerance validation, including § 12 Amendment 1 for v0.8.12.
