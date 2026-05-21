---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, multipart, large-file]
summary: Multipart upload — large files via initiate / part / complete protocol.
---

# Multipart upload

For files larger than ~5MB, the simple `POST /api/files/upload` is inefficient (single request → request size limits, no retry per-chunk, no progress UI). Multipart upload splits the file into 5MB+ parts.

## Protocol

```mermaid
graph TD
    A[POST /api/files/multipart/initiate]
    A --> B[server:<br/>1. create multipart_upload_session row<br/>2. S3 InitiateMultipartUpload<br/>3. return sessionId, uploadId]
    B --> C[client splits file into 5MB+ parts]
    C --> D[for each part:<br/>PUT /api/files/multipart/{sessionId}/part/{n}]
    D --> E[server uploads to S3 + records ETag]
    E --> F[POST /api/files/multipart/{sessionId}/complete]
    F --> G[server:<br/>1. S3 CompleteMultipartUpload<br/>2. INSERT file row<br/>3. return File DTO]
```

## Endpoints

```
POST /api/files/multipart/initiate
{ filename, contentType, totalBytes }
→ { sessionId, uploadId }

PUT /api/files/multipart/{sessionId}/part/{partNumber}
Body: raw bytes of the part
→ { partNumber, eTag }

POST /api/files/multipart/{sessionId}/complete
{ entityType, entityId }
→ File DTO

POST /api/files/multipart/{sessionId}/abort
→ 204 No Content
```

## Part requirements

- Min 5MB per part (S3 requirement) except the final part.
- Max 10,000 parts per upload.
- Parts can be uploaded in any order, in parallel.
- Server validates `partNumber` is in [1, 10000].

## Session expiry

`multipart_upload_session.expires_at` defaults to `created_at + 24 hours`. After expiry, a background job calls `S3.AbortMultipartUploadAsync` and deletes the session row. Stops S3 from charging for orphaned partial uploads.

## Frontend integration

`<FileUploadButton>` auto-switches to multipart for files > 5MB:

```tsx
<FileUploadButton
  entityType="Job"
  entityId={jobId}
  systemId={systemId}
  multipart={file => file.size > 5_000_000}   // optional, default true
  onProgress={(percent) => setProgress(percent)}
/>
```

The component:

1. Calls `/initiate` once.
2. Splits the file into 5MB chunks via `Blob.slice()`.
3. Uploads chunks in parallel (up to 4 concurrent).
4. On all complete, calls `/complete`.
5. Reports progress via `onProgress`.

## Retry per part

A failed PART can be retried without restarting the whole upload. Just PUT to `/part/{n}` again with the same `n`. Server replaces the previous part's ETag.

If the entire session times out (24h), call `/initiate` again.

## Related

- [`architecture.md`](architecture.md) — `S3Helper.InitiateMultipartUploadAsync`.
- [`signed-urls.md`](signed-urls.md) — sibling read flow.
