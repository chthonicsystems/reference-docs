---
library: work
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [work, job, spine]
summary: Job spine — what the slimmed v0.1.0 owns vs split-off concerns.
---

# Job spine

PR 13 of the extraction sequence "slimmed" Job — moved several concerns to other libraries:

| Pre-extraction TT had | Now lives in |
|---|---|
| `Job.Notes` (junction) | `@chthonic/notes` (polymorphic FK) |
| `JobPhoto` | `@chthonic/files` (polymorphic FK) |
| `Job.JobFieldValues` (custom fields) | `@chthonic/views` (`entity_field_value`) |
| `Job.Comments` | `@chthonic/work` (kept — system-emitted) |
| `JobApproval` workflow | `@chthonic/work` (kept) |
| `JobMechanic` (multi-mechanic) | `@chthonic/work` (kept) |
| `JobPartsInstalled`, `JobLaundry`, `JobInspection` | dropped as dead code in PR 13 |

## What's left

`Job` + `JobMechanic` + `JobApproval` + `JobComment`. Auto-comments + status validation + multi-mechanic assignment. That's the spine.

Custom fields (oil level, parts cost, etc.) attach via `@chthonic/views.entity_field_value(entity_type='Job', entity_id=jobId)`.

Photos attach via `@chthonic/files.file(entity_type='Job', entity_id=jobId)`.

User comments / customer-visible notes attach via `@chthonic/notes.note(entity_type='Job', entity_id=jobId)`.

## Why slim

A library called "work" should own only the workflow vocabulary — what the platform calls a "job". Cross-cutting features (notes, files, views, comments) should be reusable, not job-specific. PR 13 enforced this.

## Related

- [`architecture.md`](architecture.md), [`index.md`](index.md).
- [`libraries/notes/`](../notes/), [`libraries/files/`](../files/), [`libraries/views/`](../views/).
