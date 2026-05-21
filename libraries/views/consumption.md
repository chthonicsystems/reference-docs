---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/views`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Views" Version="0.5.0" />
```

```json
"@chthonicsystems/views": "0.5.2"
```

## 2. Implement IDbContextProvider

```csharp
public class MyDbContextProvider : IDbContextProvider
{
    private readonly TorqueTechDbContext _db;
    public MyDbContextProvider(TorqueTechDbContext db) => _db = db;
    public DbContext GetDbContext() => _db;
}
builder.Services.AddScoped<IDbContextProvider, MyDbContextProvider>();
```

## 3. Implement auto providers (per consumer entity type)

```csharp
public class JobAutoScreenProvider : IAutoScreenProvider<Job>
{
    public Task<List<AutoScreen>> GetAutoScreensAsync(int systemId, int jobId) { /* ... */ }
}

public class JobAutoOptionsProvider : IAutoOptionsProvider
{
    public Task<List<FieldOption>> GetOptionsAsync(int systemId, string fieldName) { /* ... */ }
}

builder.Services.AddScoped<IAutoScreenProvider<Job>, JobAutoScreenProvider>();
builder.Services.AddScoped<IAutoOptionsProvider, JobAutoOptionsProvider>();
```

## 4. Register Views

```csharp
builder.Services.AddChthonicViews();
app.MapChthonicViewsEndpoints();
```

## 5. Frontend bootstrap

```tsx
import { setHttpAdapter, ScreenSectionsRenderer } from '@chthonicsystems/views';
import { httpService } from '../services/httpService';

setHttpAdapter(httpService);

<ScreenSectionsRenderer
  entityType="Job"
  entityId={jobId}
  systemId={systemId}
  userId={userId}
/>
```

## 6. Verification

- [ ] `GET /api/system-views?entityType=Job` returns the tenant's views.
- [ ] `<ScreenSectionsRenderer>` renders dynamic fields based on user's role + entity status.
- [ ] Field values persist via `PUT /api/system-entity-fields/values`.
- [ ] Linked fields update target entity (e.g. ServiceItem.Cost).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`custom-fields.md`](custom-fields.md), [`screen-sections-renderer.md`](screen-sections-renderer.md), [`auto-providers.md`](auto-providers.md).
