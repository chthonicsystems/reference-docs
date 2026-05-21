---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, auto-providers, extension-points]
summary: IAutoScreenProvider<T> + IAutoOptionsProvider — runtime sections + dropdown options.
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

- [`extension-points.md`](extension-points.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`custom-fields.md`](custom-fields.md).
