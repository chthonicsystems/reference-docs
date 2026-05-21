---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, architecture, schema]
summary: Files library internals — S3Helper, ImageProcessor, FileService, multipart sessions.
---

# Architecture

## File layout

```
src/Chthonic.Files/
├── S3Helper.cs / IS3Helper.cs        # AWS S3 wrapper (PUT, GET, DELETE, presign, multipart)
├── ImageProcessor.cs / IImageProcessor.cs  # ImageSharp wrapper
├── Services/FileService.cs / IFileService.cs # primary CRUD
├── Endpoints/FileEndpoints.cs        # /api/files/*
├── Domain/
│   ├── File.cs
│   ├── MultipartUploadSession.cs
│   └── FilePurpose.cs                # enum: Photo, Document, Logo, Avatar, ...
├── Configuration/FileConfiguration.cs
├── Migrations/                       # ChthonicFiles_0001_Initial
├── FilesModuleMarker.cs
└── ServiceCollectionExtensions.cs
```

## S3Helper API

```csharp
public interface IS3Helper
{
    Task<string> PutAsync(string key, Stream content, string contentType);
    Task<Stream> GetAsync(string key);
    Task DeleteAsync(string key);
    Task<string> GeneratePresignedGetUrlAsync(string key, TimeSpan ttl);
    Task<string> InitiateMultipartUploadAsync(string key, string contentType);
    Task<string> UploadPartAsync(string key, string uploadId, int partNumber, Stream part);
    Task CompleteMultipartUploadAsync(string key, string uploadId, IReadOnlyList<(int PartNumber, string ETag)> parts);
    Task AbortMultipartUploadAsync(string key, string uploadId);
}
```

S3 key convention: `{system_id}/{entity_type}/{entity_id}/{file_id}-{slug}`.

## FileService API

```csharp
public interface IFileService
{
    Task<File> UploadAsync(int systemId, string entityType, int entityId, Stream content, string filename, string contentType, int uploadedBy);
    Task<List<File>> ListAsync(int systemId, string entityType, int entityId);
    Task<File?> GetAsync(int fileId);
    Task DeleteAsync(int fileId);
    Task<string> GetSignedUrlAsync(int fileId, TimeSpan? ttl = null);

    // Multipart for large files
    Task<MultipartUploadSession> InitiateMultipartAsync(int systemId, string filename, string contentType, long totalBytes);
    Task<UploadPartResult> UploadPartAsync(string sessionId, int partNumber, Stream content);
    Task<File> CompleteMultipartAsync(string sessionId, string entityType, int entityId, int uploadedBy);
}
```

## DB-blob fallback

Pre-extraction TT photos lived in `job_photo.photo` blob columns. Post-PR-07, every NEW upload goes to S3. Legacy reads fall back to `file.blob_data` if `file.s3_key` is null.

```csharp
// FileService.GetSignedUrlAsync
if (file.S3Key is not null)
    return await _s3.GeneratePresignedGetUrlAsync(file.S3Key, ttl);
// Legacy: serve via /api/files/{id}/raw which streams blob_data
return $"/api/files/{file.FileId}/raw";
```

A migration job (`MigrateLegacyFilesToS3 BackgroundService`) gradually copies `blob_data` → S3 + sets `s3_key` + clears `blob_data`. When complete, the `blob_data` column is dropped in a future migration.

## ImageSharp processing

`IImageProcessor.ResizeAsync(stream, maxWidth, maxHeight, quality)` returns a derived stream. Used for thumbnails + photo optimisation on upload.

The library auto-detects content type and:
- For `image/*` → resize to `maxWidth=2400` (configurable) + re-encode at quality 85.
- For non-image → upload as-is.

## Tests

| File | Coverage |
|---|---|
| `S3HelperTests` | Mocked AWS S3; PUT / GET / DELETE / presign / multipart |
| `ImageProcessorTests` | Resize, format convert, quality |
| `FileServiceTests` | Upload + list + signed URL + delete + multipart flow |
| `FileEndpointsTests` | Endpoint integration with DI |

## Related

- [`index.md`](index.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`polymorphic-fk.md`](polymorphic-fk.md), [`signed-urls.md`](signed-urls.md), [`multipart-upload.md`](multipart-upload.md), [`db-blob-fallback.md`](db-blob-fallback.md).
- [RFC 0007](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0007-files-and-uploads.md).
