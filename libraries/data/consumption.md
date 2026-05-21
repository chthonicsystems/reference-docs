---
library: data
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [data, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/data`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.Data" Version="0.1.0" />
```

## 2. Register DI

```csharp
using Chthonic.Data;
builder.Services.AddChthonicData(builder.Configuration);
app.MapDataExportEndpoints();
```

## 3. Endpoints

```
POST   /api/data-export                # request export
GET    /api/data-export                # list current user's requests
GET    /api/data-export/{id}           # status
GET    /api/data-export/{id}/download  # signed URL when status=Ready
```

## 4. Frontend

```tsx
import { RequestDataExport } from '@chthonicsystems/data';
<RequestDataExport systemId={systemId} />
```

## Verification

- [ ] `POST /api/data-export` returns Pending status.
- [ ] Background consumer transitions Pending → Processing → Ready.
- [ ] SQLite file downloadable; opens in `sqlite3` CLI.
- [ ] Per-tier quota blocks excess requests.

## Related

- [`sqlite-export.md`](sqlite-export.md), [`per-tenant-bundling.md`](per-tenant-bundling.md).
