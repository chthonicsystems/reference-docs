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

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`custom-fields.md`](custom-fields.md), [`entity-field-discriminator.md`](entity-field-discriminator.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`auto-providers.md`](auto-providers.md).
- Library repo: [chthonicsystems/views](https://github.com/chthonicsystems/views).
- [RFC 0010](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0010-views-and-custom-fields.md).
