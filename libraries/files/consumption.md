---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/files`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Files" Version="0.1.2" />
```

```json
"@chthonicsystems/files": "0.1.2"
```

## 2. AWS / S3 setup

```bash
AWS_REGION=ap-southeast-1
AWS_S3_BUCKET=torque-tech-media-prod          # or per-product
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

Bucket lifecycle: media bucket has a 30-day Glacier rule for low-frequency access. Versioning on. Public access blocked; signed URLs only.

## 3. Register DI

```csharp
using Chthonic.Files;
builder.Services.AddChthonicFiles(builder.Configuration);
app.MapFileEndpoints();
```

## 4. EF migration registration

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(FilesModuleMarker).Assembly);
```

## 5. Upload from a service

```csharp
public class JobPhotoService(IFileService files)
{
    public async Task<File> UploadAsync(int jobId, IFormFile photo, int userId)
    {
        using var stream = photo.OpenReadStream();
        return await files.UploadAsync(
            systemId: _currentSystem.Id,
            entityType: "Job",
            entityId: jobId,
            content: stream,
            filename: photo.FileName,
            contentType: photo.ContentType,
            uploadedBy: userId
        );
    }
}
```

## 6. Frontend — `<FileUploadButton>`

```tsx
import { FileUploadButton, FileGallery } from '@chthonicsystems/files';

<FileUploadButton
  entityType="Job"
  entityId={jobId}
  systemId={systemId}
  accept="image/*"
  multipart={file.size > 5 * 1024 * 1024}
  onUploaded={(file) => console.log('uploaded', file)}
/>

<FileGallery
  entityType="Job"
  entityId={jobId}
  systemId={systemId}
/>
```

`<FileUploadButton>` auto-switches to multipart for files > 5MB.

## 7. Multipart upload (manual)

```csharp
var session = await files.InitiateMultipartAsync(systemId, "video.mp4", "video/mp4", 50_000_000);
for (int i = 0; i < parts.Count; i++)
    await files.UploadPartAsync(session.SessionId, i + 1, parts[i]);
var file = await files.CompleteMultipartAsync(session.SessionId, "Job", jobId, userId);
```

Each part 5MB minimum (S3 requirement) except the final.

## 8. Endpoints

```
POST   /api/files/upload                       # single-part
POST   /api/files/multipart/initiate
PUT    /api/files/multipart/{sessionId}/part/{n}
POST   /api/files/multipart/{sessionId}/complete

GET    /api/files?entityType=Job&entityId=42   # list
GET    /api/files/{id}                         # metadata
GET    /api/files/{id}/url                     # signed URL
GET    /api/files/{id}/raw                     # legacy blob fallback
DELETE /api/files/{id}
```

## 9. Verification

- [ ] New uploads land in S3 (bucket + key visible).
- [ ] `<FileGallery>` renders thumbnails + handles signed URL TTL refresh.
- [ ] Legacy DB-blob photos still serve via `/raw`.
- [ ] Multipart upload completes 50MB+ files.
- [ ] Audit log writes `file.created` on every upload.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`polymorphic-fk.md`](polymorphic-fk.md), [`signed-urls.md`](signed-urls.md), [`multipart-upload.md`](multipart-upload.md).
