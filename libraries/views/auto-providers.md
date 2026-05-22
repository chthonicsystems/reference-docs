---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, auto-providers, extension-points, per-service-screens]
summary: IAutoScreenProvider<T> + IAutoOptionsProvider — runtime sections + dropdown options, with per-service worked example.
---

# Auto providers

Two extension interfaces let consumers inject runtime data into `<ScreenSectionsRenderer>` without storing it as static `system_entity_field*` rows.

## IAutoScreenProvider<TEntity>

Adds **auto-generated screens/sections** at render time. Used for sections whose content comes from another entity:

```csharp
public class JobAutoScreenProvider : IAutoScreenProvider<Job>
{
    private readonly TorqueTechDbContext _db;
    public JobAutoScreenProvider(TorqueTechDbContext db) => _db = db;

    public async Task<List<AutoScreen>> GetAutoScreensAsync(int systemId, int jobId)
    {
        var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(j => j.JobId == jobId);
        return new List<AutoScreen>
        {
            new()
            {
                ScreenName = "Vehicle Info",
                Sections = new List<AutoSection>
                {
                    new()
                    {
                        Name = "Identification",
                        Fields = new List<AutoField>
                        {
                            new() { Label = "Make", Value = ((Vehicle)job.Asset).Make },
                            new() { Label = "Model", Value = ((Vehicle)job.Asset).Model },
                            new() { Label = "VIN", Value = ((Vehicle)job.Asset).Vin },
                        }
                    }
                }
            }
        };
    }
}

builder.Services.AddScoped<IAutoScreenProvider<Job>, JobAutoScreenProvider>();
```

The library merges auto-screens with admin-defined views; the user sees both.

### Per-service worked example

Service-driven products (workshop, marina, forklift fleet, veterinary clinic) typically want one screen per linked service on a job, drawn from the items in that service's catalog. The same `IAutoScreenProvider<TEntity>` interface covers it — loop over the entity's linked services and emit one `AutoScreen` per service:

```csharp
public class JobServiceAutoScreenProvider : IAutoScreenProvider<Job>
{
    private readonly TorqueTechDbContext _db;
    public JobServiceAutoScreenProvider(TorqueTechDbContext db) => _db = db;

    public async Task<List<AutoScreen>> GetAutoScreensAsync(int systemId, int jobId)
    {
        // Load every service linked to the job, plus the catalog items
        // (and field definitions) attached to each service.
        var services = await _db.JobServices
            .Where(js => js.JobId == jobId)
            .Select(js => new
            {
                js.ServiceId,
                ServiceName = js.Service.Name,
                Items = js.Service.ServiceItems
                    .SelectMany(si => si.JobFields.Select(jf => new
                    {
                        Label = jf.Label,
                        Value = jf.GetDefaultFor(jobId),   // pulled from ServiceItem.Cost / Product / etc.
                    }))
                    .ToList(),
            })
            .ToListAsync();

        return services.Select(s => new AutoScreen
        {
            ScreenName = s.ServiceName,
            Sections = new List<AutoSection>
            {
                new()
                {
                    Name = "Items",
                    Fields = s.Items
                        .Select(i => new AutoField { Label = i.Label, Value = i.Value })
                        .ToList(),
                }
            }
        }).ToList();
    }
}

builder.Services.AddScoped<IAutoScreenProvider<Job>, JobServiceAutoScreenProvider>();
```

The result is one screen per service on every job — `Brake service`, `Test ride`, `Major service`, etc. — without the admin having to pre-design any of them.

### Configured vs auto-generated per-service screens

Two modes coexist by design:

- **Configured per-service screens** — a `system_view` row exists with a non-null `service_id` (see [`architecture.md`](architecture.md) § Per-service variant). Preferred when admins want full control over the screen layout, section grouping, or field visibility per service. Stored in the `system_entity_field*` rows for that view, the same as any other view's screens.
- **Auto-generated per-service screens** — no `system_view` exists for the service. The provider above synthesises a screen at render time from the service's catalog rows (items, products, linked field definitions). Nothing is persisted on the view side.

Consumers commonly expose this as two boolean flags on the host view, `include_service_screens` and `auto_service_screens`, so admins can opt in or out of the merge per host view. Configured screens take precedence over auto-generated ones for the same service — when a workshop designs a custom screen for "Brake service", the auto-generated version stops appearing for that service, and the rest keep auto-generating.

## IAutoOptionsProvider

Returns dropdown options at runtime (instead of from `system_entity_field_option`):

```csharp
public class MyAutoOptionsProvider : IAutoOptionsProvider
{
    public async Task<List<FieldOption>> GetOptionsAsync(int systemId, string fieldName)
    {
        return fieldName switch
        {
            "assigned_mechanic" => await GetMechanicsAsync(systemId),
            "service_id"        => await GetServicesAsync(systemId),
            _                   => null,   // fall back to system_entity_field_option
        };
    }
}
```

When a `<FieldRenderer>` for an `Options` field invokes the provider with the field's name, returning a non-null list takes precedence over static options.

## Lifecycle

Both interfaces are scoped per request. They have access to the current request's DbContext, user, and authorization context.

## Related

- [`architecture.md`](architecture.md) § Per-service variant — the schema-side companion to the per-service worked example above.
- [`extension-points.md`](extension-points.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`custom-fields.md`](custom-fields.md).
