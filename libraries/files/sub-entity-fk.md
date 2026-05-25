---
library: files
version: 0.2.0
related-rfcs: [0007, 0024]
last-verified: 2026-05-26
tags: [files, polymorphic-fk, sub-entity, two-level-fk]
summary: v0.2.0 generalization of the polymorphic FK pattern to two levels — primary owner + optional secondary owner.
---

# Sub-entity FK (two-level polymorphic FK)

`@chthonicsystems/files` v0.2.0 generalizes the polymorphic FK pattern
from one level to two: a primary owner (`entity_type` / `entity_id`)
and an optional secondary owner (`sub_entity_type` / `sub_entity_id`).
Per [RFC 0024 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26).

## Why two levels

Some consumer concepts are children of a primary entity but worth
attaching files to directly. For example, a QC evidence photo on a
Job belongs to the Job (primary) but is also linked to a specific
QcSignoffItemResult (secondary). With one level only, the consumer
has to choose between:

- Coarse: `entity_type='Job', entity_id=jobId` — "all files for job"
  query is trivial; per-result query needs an extra join.
- Fine: `entity_type='QcSignoffItem', entity_id=resultId` — per-result
  query is trivial; "all files for job" needs a custom aggregation.

Two levels gives both queries trivially:

| Question | Query |
|---|---|
| All media for job 42 (Job Photos page) | `WHERE entity_type='Job' AND entity_id=42` |
| Identify QC evidence rows in that result set | `sub_entity_type='QcSignoffItem'` (no JOIN needed for the discriminator) |
| Photos for QC result 88 (QC tab attachment slot) | `WHERE sub_entity_type='QcSignoffItem' AND sub_entity_id=88` |
| Resolve the QC field label for a tile | `JOIN qc_signoff_item_result ON sub_entity_id … JOIN entity_field` (one denormalized query) |

## Schema

```sql
file
  file_id           int PK
  system_id         int
  entity_type       varchar(50)              -- 'Job' (primary)
  entity_id         int                       -- jobId
  sub_entity_type   varchar(50) NULL          -- 'QcSignoffItem' (secondary; nullable)
  sub_entity_id     int NULL                  -- resultId (nullable)
  purpose           int                       -- FilePurpose enum
  ...other columns...

  index ix_file_entity     (entity_type, entity_id)               -- existing primary
  index ix_file_sub_entity (sub_entity_type, sub_entity_id)        -- NEW v0.2.0
```

Both columns are nullable. Pre-v0.2.0 file rows have `sub_entity_*` =
`NULL` and continue to work unchanged.

`multipart_upload_session` carries the same two columns so the
sub-entity tags survive multipart resumes.

## Convention strings

| `sub_entity_type` | Owning consumer | Use case |
|---|---|---|
| `QcSignoffItem` | TT (PR 05 / F3) | QC evidence files attached to `qc_signoff_item_result` |
| `Walkaround` | TT (planned F10) | Vehicle walkaround photos |
| `LabourEntry` | (future) | Per-clock-in evidence (if any product needs it) |

The library doesn't validate values — consumers supply arbitrary
strings. The convention strings table extends per consumer's needs.

## Public API

### Backend (C#)

```csharp
// IFileService.UploadAsync — back-compat preserved via default-null
public Task<File> UploadAsync(
    UploadRequest request,    // SubEntityType + SubEntityId optional
    Stream content,
    CancellationToken ct = default);

public sealed record UploadRequest(
    int SystemId,
    string EntityType,
    int EntityId,
    string FileName,
    string MimeType,
    FilePurpose Purpose,
    string? Caption = null,
    int? UploadedByUserId = null,
    int? UploadedByCustomerId = null,
    bool ResizeIfImage = true,
    string? SubEntityType = null,    // v0.2.0+
    int? SubEntityId = null);         // v0.2.0+
```

### Frontend (npm)

```ts
// Pass-through props on the upload + gallery components
<FileUploadButton
  entityType="Job"
  entityId={jobId}
  subEntityType="QcSignoffItem"
  subEntityId={resultId}
  purpose="Photo"
/>

<FileGallery
  entityType="Job"
  entityId={jobId}
  filterBySubEntity={{ type: 'QcSignoffItem', id: 88 }}
/>
```

`useFileUpload({ filterBySubEntity })` hook also supports the filter.

### `/api/files` endpoint

```
POST /api/files
  multipart/form-data fields:
    file               File
    entityType         string                       'Job'
    entityId           int                          jobId
    purpose            string                       'Photo' | 'Video' | ...
    subEntityType      string?    (v0.2.0+)          'QcSignoffItem' (optional)
    subEntityId        int?       (v0.2.0+)          resultId (optional)
    caption            string?
    resizeIfImage      bool?

GET /api/files?entityType=Job&entityId=42&subEntityType=QcSignoffItem&subEntityId=88
```

## Cascade / cleanup

The polymorphic FK has no real SQL constraint; cleanup is application-
managed (matches v0.1.x pattern). When a consumer deletes a parent
that has child sub-entity rows referencing it (e.g. a
`qc_signoff_item_result` deletion when the parent `qc_signoff` is
deleted), the application may run:

```sql
DELETE FROM file
WHERE sub_entity_type = 'QcSignoffItem'
  AND sub_entity_id IN (<deleted result ids>);
```

The orphan-detection query in
[`polymorphic-fk.md`](polymorphic-fk.md) extends naturally:

```sql
DELETE f FROM file f
LEFT JOIN qc_signoff_item_result r ON f.sub_entity_id = r.qc_signoff_item_result_id
WHERE f.sub_entity_type = 'QcSignoffItem' AND r.qc_signoff_item_result_id IS NULL
LIMIT 1000;
```

## Migration

Lib migration `ChthonicFiles_0002_AddSubEntityFK` is **idempotent** —
guards every `ALTER TABLE` with an `information_schema` check, safe
to re-run. Down-migration drops the columns + index.

## Related

- [`index.md`](index.md), [`polymorphic-fk.md`](polymorphic-fk.md), [`qc-evidence.md`](qc-evidence.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 1 (polymorphic FK pattern).
- [RFC 0024 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26)
