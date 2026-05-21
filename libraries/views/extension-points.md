---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, extension-points]
summary: Extension points — IAutoScreenProvider<T>, IAutoOptionsProvider, IDbContextProvider, http adapter.
---

# Extension points

| Hook | Layer | Use |
|---|---|---|
| `IAutoScreenProvider<TEntity>` | .NET | Per-entity auto-section provider (e.g. system fields, computed sections) |
| `IAutoOptionsProvider` | .NET | Per-field auto-options (e.g. mechanic dropdown reads from users table) |
| `IDbContextProvider` (port) | .NET | Bridge to consumer DbContext |
| `setHttpAdapter(httpService)` | npm | Bridge to consumer HTTP layer |

## IAutoScreenProvider

```csharp
public interface IAutoScreenProvider<TEntity>
{
    Task<List<AutoScreen>> GetAutoScreensAsync(int systemId, int entityId);
}
```

Returns auto-generated sections that mix into the user's resolved view. Consumer scenarios:

- TT's `JobAutoScreenProvider` → adds a "Vehicle Info" auto-section that reads from `Vehicle` (joined via `Job.VehicleId`).
- A "Comments" auto-section that lazy-loads job comments.

Auto-sections render alongside admin-defined sections in `<ScreenSectionsRenderer>`.

## IAutoOptionsProvider

```csharp
public interface IAutoOptionsProvider
{
    Task<List<FieldOption>> GetOptionsAsync(int systemId, string fieldName);
}
```

Returns dropdown options at runtime instead of from `system_entity_field_option`. Useful for fields that mirror data tables:

- `assigned_mechanic` field → options are users with role 'mechanic'.
- `customer_id` field → options are customer search results.

## Custom field types

The library ships these data types: `Text`, `Numeric`, `Date`, `Checkbox`, `Options`, `Combo`, `MultiValueOptions`. Adding a new type (e.g. `Image`):

1. Add to `EntityFieldDataType` enum.
2. Author a `<ImageField>` React component.
3. Register in the field-component map in `<FieldRenderer>`.
4. Bump minor version.

## Cross-library FK linkage

`linked_field_name` on `system_entity_field` references columns in other tables. Pattern: `<table>.<column>`. E.g. `service_item.cost` links a job's "Total Cost" field to a service item's cost. Per PR 11.5 the library treats these as FK-only — no nav properties — so adding a new linked entity is just a string convention.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`custom-fields.md`](custom-fields.md), [`auto-providers.md`](auto-providers.md).
