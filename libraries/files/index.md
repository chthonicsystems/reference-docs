---
library: files
package-nuget: Chthonic.Files
package-npm: '@chthonicsystems/files'
version: 0.2.0
related-rfcs: [0007]
related-libs: [audit, tenant]
last-verified: 2026-05-22
tags: [core-domain, storage, s3, polymorphic-fk, multipart-upload]
summary: S3 + ImageSharp + signed URLs + polymorphic FK + multipart upload + DB-blob fallback.
---

# `@chthonicsystems/files` / `Chthonic.Files`

Centralised file storage for every product. Polymorphic FK pattern (`(entity_type, entity_id)`) lets any library attach files to any entity.

## Purpose

- S3-backed file storage with `ImageSharp`-driven image processing (resize, format convert).
- Signed-URL generation for time-limited access.
- Polymorphic attachment — `file.entity_type` is a consumer-supplied string.
- Multipart upload sessions for large files.
- Legacy DB-blob fallback (gradually migrating off; new uploads go to S3).
- Shells: `<FileGallery>`, `<FileUploadButton>`.

## Public surface

### .NET

| Type | File | Role |
|---|---|---|
| `IFileService` / `FileService` | `src/Chthonic.Files/Services/FileService.cs` | Upload, list, delete, signed URLs |
| `IS3Helper` / `S3Helper` | `src/Chthonic.Files/S3Helper.cs` | Low-level S3 wrapper (PUT, GET, DELETE, presign) |
| `IImageProcessor` / `ImageProcessor` | `src/Chthonic.Files/ImageProcessor.cs` | ImageSharp-driven resize / format / quality |
| `MapFileEndpoints` | `src/Chthonic.Files/Endpoints/FileEndpoints.cs` | `/api/files/*` |
| `services.AddChthonicFiles(config)` | `src/Chthonic.Files/ServiceCollectionExtensions.cs` | DI entry point |

**Domain entities:** `File`, `MultipartUploadSession`. EF migration `ChthonicFiles_0001_Initial`.

### npm

| Export | Role |
|---|---|
| `<FileGallery entityType entityId>` | Grid of attached files |
| `<FileUploadButton entityType entityId>` | Multipart-aware upload trigger |
| `useFiles({ entityType, entityId })` | Hook for paginated file list |

## Schema

```
file
  file_id           int PK
  system_id         int FK
  entity_type       varchar(50)    'Job', 'Vehicle', 'Customer', 'Note', 'Vessel', 'Pet', ...
  entity_id         int
  sub_entity_type   varchar(50)?   v0.2.0+ — secondary owner ('QcSignoffItem', 'Walkaround', ...)
  sub_entity_id     int?           v0.2.0+ — paired with sub_entity_type
  purpose           int            FilePurpose enum (Photo, Video [v0.2.0+], Document, Avatar, Logo, ...)
  filename          varchar(255)
  content_type      varchar(100)
  size_bytes        bigint
  s3_key            varchar(500)?  null = legacy DB-blob fallback
  blob_data         longblob?      null after S3 migration
  uploaded_by       int FK → users
  uploaded_at       datetime
  deleted_at        datetime?

  index ix_file_entity     (entity_type, entity_id)         -- existing primary FK index
  index ix_file_sub_entity (sub_entity_type, sub_entity_id) -- v0.2.0+ secondary FK index
  index ix_file_system     (system_id)

multipart_upload_session
  session_id        varchar(36) PK
  system_id         int
  filename          varchar(255)
  content_type      varchar(100)
  total_bytes       bigint
  upload_id         varchar(200)   S3 multipart upload id
  parts_uploaded    int
  expires_at        datetime
  created_at        datetime
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/audit` | File create/delete writes audit rows |
| `@chthonic/tenant` | `system_id` scoping |
| `AWSSDK.S3` (4.x) | S3 client |
| `SixLabors.ImageSharp` | Image resize/convert |

## Extension points

| Hook | Use |
|---|---|
| `IS3Helper` | Override for non-AWS S3 (Backblaze B2, MinIO, Cloudflare R2) |
| `IImageProcessor` | Override for different image library |
| `entity_type` polymorphic FK | Each consumer supplies arbitrary type strings |
| `services.AddChthonicFiles(opts => opts.SignedUrlTtl = TimeSpan.FromHours(2))` | Per-product signed-URL TTL |

## Consuming this library

```csharp
using Chthonic.Files;
builder.Services.AddChthonicFiles(builder.Configuration);
app.MapFileEndpoints();
```

```tsx
import { FileGallery, FileUploadButton } from '@chthonicsystems/files';

<FileUploadButton entityType="Job" entityId={jobId} systemId={systemId} />
<FileGallery     entityType="Job" entityId={jobId} systemId={systemId} />
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`polymorphic-fk.md`](polymorphic-fk.md), [`sub-entity-fk.md`](sub-entity-fk.md) (v0.2.0+), [`qc-evidence.md`](qc-evidence.md) (TT pattern), [`signed-urls.md`](signed-urls.md), [`multipart-upload.md`](multipart-upload.md), [`db-blob-fallback.md`](db-blob-fallback.md).
- Library repo: [chthonicsystems/files](https://github.com/chthonicsystems/files).
- [RFC 0007](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0007-files-and-uploads.md).
