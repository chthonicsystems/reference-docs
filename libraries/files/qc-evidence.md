---
library: files
version: 0.2.0
related-rfcs: [0024]
related-libs: [tenant, work, views]
last-verified: 2026-05-26
tags: [files, qc, evidence, sub-entity-fk, video, tier-limit]
summary: TT-specific QC evidence pattern — sub_entity_type='QcSignoffItem' + Purpose=Photo|Video + per-tenant MaxVideoSizeBytes tier_limit + cross-page surface on Job Photos.
---

# QC evidence (TT consumer pattern)

PR 05 (F3 Photo + Video QC Evidence) ships QC evidence as a
TorqueTech-side composition over `@chthonicsystems/files` v0.2.0's
[two-level polymorphic FK](sub-entity-fk.md). Per
[RFC 0024 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26).

## How files are tagged

| File kind | `entity_type` | `entity_id` | `sub_entity_type` | `sub_entity_id` | `purpose` |
|---|---|---|---|---|---|
| Regular Job photo | `Job` | jobId | NULL | NULL | `Photo` |
| QC evidence photo | `Job` | jobId | `QcSignoffItem` | `qcSignoffItemResultId` | `Photo` |
| QC evidence video | `Job` | jobId | `QcSignoffItem` | `qcSignoffItemResultId` | `Video` |

The primary FK stays `(entity_type='Job', entity_id=jobId)` for **all**
job-related files. This keeps the JobPhotos page query trivially:

```sql
SELECT * FROM file
WHERE entity_type='Job' AND entity_id=:jobId AND deleted_at IS NULL
ORDER BY uploaded_at DESC
```

QC evidence rows are identified by the non-null `sub_entity_type` /
`sub_entity_id` columns; no second polymorphic class needed.

## Capture-and-attach UX (autosave-on-attach)

```
1. Mechanic taps pass/fail on a `boolean-attachment` or
   `number-attachment` field in the QC tab.
2. Mechanic taps the Photo / Video / Library button in the field's
   evidence slot.
3. Frontend calls useQcEvidenceAutosaver.ensureDraftSaved() —
   idempotent: if no draft exists, fires POST /api/jobs/:id/qc/signoff/save
   and caches the entityFieldId → qcSignoffItemResultId map. If a
   draft already exists, returns the cached map.
4. With the resultId in hand, the FE captures via
   useMediaCapture (mobile-runtime v0.3.0+).
5. Captured Blob uploads to POST /api/files with
   entityType='Job', entityId=jobId,
   subEntityType='QcSignoffItem', subEntityId=resultId,
   purpose='Photo' | 'Video'.
6. Server applies VideoSizeCappedFileService decorator (TT-side):
   for purpose='Video', reads MaxVideoSizeBytes via ILimitService;
   413 video-size-exceeded if oversized.
7. After lib's IFileService.UploadAsync inserts the file row, TT's
   QcSignoffOrchestrator.BindFilesToResultsAsync (called in
   SaveDraft / Submit wrappers) ensures the file row's
   sub_entity_type / sub_entity_id stay in sync with the
   QcItemResult.FileIds plumbing slot from the work lib's input.
```

## Per-tenant video size cap

The cap is a string-keyed `tier_limit` named `"MaxVideoSizeBytes"`
(default 50 MB = 52,428,800 bytes). Default seeded by TT's
`SeedTierEntitlementsAndVideoSizeCap` migration (Free / Standard /
Premium all 50 MB). Per-tenant override via
`feature_override.IntValue` with the standard precedence chain.

The `-1` sentinel ("unlimited") is honoured.

## Endpoint contracts

### Save draft → returns resultId map

```
POST /api/jobs/{id}/qc/signoff/save
{ "results": [{ "entityFieldId": 412, "value": "true" }, ...] }

→ 200 OK
{
  "qcSignoffId": 30,
  "jobId": 42,
  "viewId": 7,
  "status": "InProgress",
  "signedAt": "2026-05-26T...",
  "results": [
    { "qcSignoffItemResultId": 88, "entityFieldId": 412 },
    ...
  ]
}
```

The `results` array is the v0.2.0 addition that PR 05 adds — needed
so the FE can map `entityFieldId → qcSignoffItemResultId` for the
sub-entity FK on subsequent uploads.

### Upload evidence

```
POST /api/files
multipart/form-data:
  file               <Blob>
  entityType         Job
  entityId           42
  subEntityType      QcSignoffItem
  subEntityId        88
  purpose            Photo  (or Video)

→ 201 Created
→ 413 Payload Too Large + { errorCode: "video-size-exceeded", maxSizeBytes: 52428800 }
```

### Job Photos page (cross-page surface)

```
GET /api/jobs/{id}/photos
→ 200 OK
[
  {
    "photoId": 901,                        // legacy alias for FE compat
    "fileId": 901,                          // canonical
    "url": "/api/files/901/content",
    "fileName": "brake-pad.jpg",
    "mimeType": "image/jpeg",
    "caption": null,
    "createdAt": "2026-05-26T...",
    "qcEvidenceContext": null              // regular Job photo
  },
  {
    "fileId": 902,
    "mimeType": "video/mp4",
    "qcEvidenceContext": {
      "qcSignoffItemResultId": 88,
      "qcSignoffId": 30,
      "entityFieldId": 412,
      "fieldLabel": "Brake pad thickness"   // surfaces in the QC tile badge
    }
  },
  ...
]
```

Hard limit 200 rows per response. Pagination is a post-PR follow-up
if real-world job sizes warrant it.

## Component hierarchy (web)

```
<JobScreenSections> (TT)
└─ <ScreenSectionsRenderer kind="qc"
       renderQcAttachmentSlot={(ctx) => <QcEvidenceSlot ... />}>
        └─ qc-attachment-slot
              └─ <QcEvidenceSlot> (TT)
                    ├─ <FileGallery filterBySubEntity={{ type:'QcSignoffItem', id:resultId }} /> (lib)
                    └─ Capture buttons (Photo / Video / Library)
                          gated by useFeatureGate('PhotoAttachments') /
                                   useFeatureGate('VideoAttachments') AND isVideoSupported

<JobPhotos> (TT — cross-page surface)
└─ Single chronological grid
      ├─ <AuthenticatedImage> for image/* tiles (TT)
      ├─ <AuthenticatedVideo> for video/* tiles (TT — play-icon overlay)
      └─ <QcEvidenceBadge fieldLabel /> overlay when qcEvidenceContext non-null (TT)
```

## Lib impact

| Library | Version | Role in QC evidence |
|---|---|---|
| `@chthonicsystems/files` | v0.2.0 | sub_entity FK columns + `Purpose=Video`; `<FileGallery filterBySubEntity>` |
| `@chthonicsystems/views` | v0.8.13 | `renderQcAttachmentSlot` prop on `<ScreenSectionsRenderer>` |
| `@chthonicsystems/mobile-runtime` | v0.3.0 | `useMediaCapture` (photo + video + library pick) |
| `@chthonicsystems/tenant` | v0.8.0 (BREAKING) | Tier-seed relocation (RFC 0039) — `MaxVideoSizeBytes` is the F3 trigger |
| `@chthonic/work` | v0.5.0 (no bump) | Existing `QcItemResult.FileIds` plumbing slot consumed by TT orchestrator |

## Related

- [`sub-entity-fk.md`](sub-entity-fk.md) — generalized two-level pattern
- [`polymorphic-fk.md`](polymorphic-fk.md) — primary FK pattern (predecessor)
- [`index.md`](index.md), [`signed-urls.md`](signed-urls.md), [`multipart-upload.md`](multipart-upload.md)
- [`../views/screen-sections-renderer.md`](../views/screen-sections-renderer.md) — `renderQcAttachmentSlot` prop
- [`../mobile-runtime/media-capture.md`](../mobile-runtime/media-capture.md) — `useMediaCapture` API
- [`../work/qc-signoff.md`](../work/qc-signoff.md) — QC sign-off flow
- [`../tenant/seeds.md`](../tenant/seeds.md) — tier-seed locality (RFC 0039)
- [RFC 0024 § 12 Amendment 1](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0024-photo-evidence-qc.md#12-amendment-1--implementation-diverged-from-original-design-2026-05-26)
