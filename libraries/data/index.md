---
library: data
package-nuget: Chthonic.Data
package-npm: '@chthonicsystems/data'
version: 0.1.0
related-rfcs: [0001]
related-libs: [tenant, support]
last-verified: 2026-05-22
tags: [feature, exports, sqlite]
summary: Per-tenant SQLite export. Bulk-import deferred.
---

# `@chthonicsystems/data` / `Chthonic.Data`

Per-tenant SQLite export for tenant migrations + backups. Bulk-import is deferred (future RFC).

## Purpose

A tenant admin can request an export of all their data — `system`, `users`, `customers`, `assets`, `jobs`, `bookings`, `invoices`, `estimates`, plus every related child table — packaged as a single SQLite file with an embedded README.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IDataExportService` / `DataExportService` | Request + status + download |
| `DataExportBuilder` | Builds the SQLite file from EF queries |
| `DataExportLimitService` | Per-tier export quota |
| `ArtifactCollector` | Collects supporting files (logos, photos) |
| `DataExportConsumer : BackgroundService` | RabbitMQ consumer |
| `MapDataExportEndpoints` | `/api/data-export/*` |
| `services.AddChthonicData(config)` | DI entry point |

### npm

| Export | Role |
|---|---|
| Types | `DataExport`, `DataExportStatus` |
| `<RequestDataExport>` (admin button) | Triggers export request |

## Schema

```
data_export
  data_export_id  int PK
  system_id       int
  requested_by    int FK → users
  status          enum 'Pending', 'Processing', 'Ready', 'Failed', 'Expired'
  s3_key          varchar?      # SQLite file in S3
  file_size_bytes bigint?
  requested_at    datetime
  ready_at        datetime?
  expires_at      datetime?     # default ready_at + 7 days
  error_message   text?
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id + tier limits |
| `@chthonic/support` | Failed exports auto-create support tickets |
| `Microsoft.Data.Sqlite` | SQLite write |

## Extension points

| Hook | Use |
|---|---|
| `IDataExportLimitService` override | Custom per-tier quota |
| `ArtifactCollector` override | Per-product extras (e.g. PetCare adds X-rays) |
| Schema additions | Per-product subtype columns auto-included via reflection |

## Consuming this library

```csharp
using Chthonic.Data;
builder.Services.AddChthonicData(builder.Configuration);
app.MapDataExportEndpoints();
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`sqlite-export.md`](sqlite-export.md), [`per-tenant-bundling.md`](per-tenant-bundling.md).
- Library repo: [chthonicsystems/data](https://github.com/chthonicsystems/data).
- [RFC 0001](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0001-platform-extraction.md) § @chthonic/data.
