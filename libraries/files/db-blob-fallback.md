---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, legacy, db-blob, migration]
summary: Legacy DB-blob fallback — pre-S3 photos served directly from blob_data column.
---

# DB-blob fallback

Pre-extraction TT stored job photos as `LONGBLOB` in `job_photo.photo`. PR 07 extracted to S3 + introduced this library, but legacy photos remain in DB pending background migration.

## Storage states

A `file` row is in one of three states:

| State | `s3_key` | `blob_data` | Read behaviour |
|---|---|---|---|
| **Modern (S3-only)** | non-null | null | Signed URL → S3 |
| **Legacy (DB-only)** | null | non-null | `/api/files/{id}/raw` streams from DB |
| **In-flight (dual-write)** | non-null | non-null | Signed URL preferred; DB-only fallback if S3 unavailable |

New uploads: only modern state. Existing TT photos: legacy state. Background migration shifts legacy → modern.

## Reading

```csharp
public async Task<string> GetSignedUrlAsync(int fileId, TimeSpan ttl)
{
    var file = await _db.Files.FirstAsync(f => f.FileId == fileId);
    if (file.S3Key is not null)
        return await _s3.GeneratePresignedGetUrlAsync(file.S3Key, ttl);
    return $"/api/files/{file.FileId}/raw";   // streams blob_data
}
```

The `/api/files/{id}/raw` endpoint:

```csharp
app.MapGet("/api/files/{id}/raw", async (int id, ...) =>
{
    var file = await _db.Files.FirstAsync(f => f.FileId == id);
    if (file.BlobData is null)
        return Results.NotFound();
    return Results.File(file.BlobData, file.ContentType, file.Filename);
});
```

Auth-protected. Slow for large files (DB load + transfer overhead), but functional.

## Background migration

`MigrateLegacyFilesToS3 BackgroundService` runs every 5 minutes:

```csharp
const int batchSize = 50;
var legacy = await _db.Files
    .Where(f => f.S3Key == null && f.BlobData != null)
    .Take(batchSize)
    .ToListAsync();

foreach (var file in legacy)
{
    using var stream = new MemoryStream(file.BlobData!);
    var key = $"{file.SystemId}/{file.EntityType}/{file.EntityId}/{file.FileId}-{Slug(file.Filename)}";
    await _s3.PutAsync(key, stream, file.ContentType);
    file.S3Key = key;
    file.BlobData = null;     // free DB space
    await _db.SaveChangesAsync();
}
```

Throughput: ~10,000 files/hour (depending on average size).

## Switching off the fallback

When migration is complete (`SELECT COUNT(*) FROM file WHERE s3_key IS NULL = 0`), drop the column in a future migration:

```sql
ALTER TABLE file DROP COLUMN blob_data;
```

Then remove the `/api/files/{id}/raw` endpoint + the `MigrateLegacyFilesToS3` background service.

## Why not just bulk-migrate at extraction time

Bulk-copy of GB-scale blob data from DB to S3 in one go would lock the table + saturate network. Background migration is rate-limited + observable + safe.

## Related

- [`architecture.md`](architecture.md), [`signed-urls.md`](signed-urls.md).
- [RFC 0007](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0007-files-and-uploads.md).
