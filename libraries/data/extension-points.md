---
library: data
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [data, extension-points]
summary: Extension points — IDataExportLimitService, ArtifactCollector override.
---

# Extension points

| Hook | Use |
|---|---|
| `IDataExportLimitService` | Custom per-tier quota (default: Free=1/month, Standard=5/month, Premium=unlimited) |
| `ArtifactCollector` | Per-product extras (e.g. PetCare adds X-rays from `@chthonic/files`) |
| Per-product subtype columns | Auto-included via reflection — no override needed |

## Custom limit service

```csharp
public class MyDataExportLimitService : IDataExportLimitService
{
    public Task<bool> CanRequestAsync(int systemId)
    {
        var tier = _tier.GetTierAsync(systemId).Result;
        return tier == "Premium" ? true : CountThisMonth(systemId) < 5;
    }
}

builder.Services.AddScoped<IDataExportLimitService, MyDataExportLimitService>();
```

## Custom artifact collector

```csharp
public class PetCareArtifactCollector : ArtifactCollector
{
    public override async Task<List<ExportArtifact>> CollectAsync(int systemId)
    {
        var base_ = await base.CollectAsync(systemId);
        var xrays = await _files.ListByEntityTypeAsync(systemId, "PetXray");
        base_.AddRange(xrays.Select(x => new ExportArtifact(x.S3Key, x.Filename)));
        return base_;
    }
}
```

## Related

- [`sqlite-export.md`](sqlite-export.md), [`per-tenant-bundling.md`](per-tenant-bundling.md).
