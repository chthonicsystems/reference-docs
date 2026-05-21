---
library: work
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [work, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/work`

## 1. Add package reference

```xml
<PackageReference Include="Chthonic.Work" Version="0.1.0" />
```

## 2. Register DI

```csharp
using Chthonic.Work;
builder.Services.AddChthonicWork();

// Optional: override transition rules
builder.Services.AddScoped<IJobStatusTransitionValidator, MyJobValidator>();
```

## 3. EF migration

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(WorkModuleMarker).Assembly);
```

## 4. Cross-library cast at usage

```csharp
var job = await _db.Jobs
    .Include(j => j.Asset)
    .FirstAsync(j => j.JobId == jobId);

var vehicle = (Vehicle)job.Asset;   // TT downcast
return new { vehicle.Make, vehicle.Model };
```

See [`cross-library-asset-fk.md`](cross-library-asset-fk.md).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
