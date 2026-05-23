---
library: views
package-nuget: Chthonic.Views
package-npm: '@chthonicsystems/views'
version: 0.6.0
related-rfcs: [0010, 0022]
related-libs: [tenant, audit, catalog]
last-verified: 2026-05-23
tags: [cross-cutting, custom-fields, views, screens, qc]
summary: Custom field definitions + per-role view configurations + ScreenSectionsRenderer + v0.6.0 view-kind discriminator + numeric bounds + parent-child structure for QC.
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

See [RFC 0022 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md#12-amendment-1--f1b-qc-view-defaults--opt-out-2026-05-24) for the full design rationale.

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`custom-fields.md`](custom-fields.md), [`entity-field-discriminator.md`](entity-field-discriminator.md), [`entity-field-bounds.md`](entity-field-bounds.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`auto-providers.md`](auto-providers.md).
- Library repo: [chthonicsystems/views](https://github.com/chthonicsystems/views).
- [RFC 0010](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0010-views-and-custom-fields.md).
- [RFC 0022](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0022-qc-signoff.md) — QC sign-off, including § 12 Amendment 1 for v0.8.x changes.
