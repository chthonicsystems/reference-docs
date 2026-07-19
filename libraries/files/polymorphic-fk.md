---
library: files
version: 0.1.2
related-rfcs: [0007]
last-verified: 2026-05-22
tags: [files, polymorphic-fk]
summary: Polymorphic FK pattern — file.entity_type / entity_id attaches files to any consumer entity.
---

# Polymorphic FK

The `file` table uses `(entity_type, entity_id)` to attach files to any entity in any library without a FK constraint.

> **v0.2.0+ generalization.** Files now also carry an optional
> `(sub_entity_type, sub_entity_id)` pair for child-concept ownership.
> See [`sub-entity-fk.md`](sub-entity-fk.md) for the two-level pattern
> (used by F3 QC evidence to attach to a `qc_signoff_item_result`
> while keeping the primary FK on `Job`).

## Schema

```sql
CREATE TABLE file (
    file_id INT PRIMARY KEY AUTO_INCREMENT,
    system_id INT NOT NULL,
    entity_type VARCHAR(50) NOT NULL,    -- 'Job', 'Vehicle', 'Customer', 'Vessel', 'Pet', ...
    entity_id INT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    -- ...
    INDEX ix_file_entity (entity_type, entity_id)
);
```

No FK on `(entity_type, entity_id)` — the library doesn't know what entities exist in consumer products.

## Why no FK

A FK from `file` to a parent table requires the parent table to exist at compile + run time. With multiple consumer products, the same `file` table serves rows attached to `Vehicle` (TT), `Vessel` (MarineDeck), `Forklift` (FlowLift), `Pet` (PetCare). A FK can only point at one of these.

## Trade-off — orphan handling

If `Job 42` is deleted, dangling `file` rows with `entity_type='Job', entity_id=42` remain. The library provides:

```csharp
await _files.DeleteByEntityAsync("Job", 42);
```

…to be called by the consumer's job-delete service. Or run a periodic orphan-detection job:

```sql
DELETE f FROM file f
LEFT JOIN job j ON f.entity_type = 'Job' AND f.entity_id = j.job_id
WHERE f.entity_type = 'Job' AND j.job_id IS NULL
LIMIT 1000;
```

## Convention strings

| entity_type | Owning library | Example |
|---|---|---|
| `Job` | `@chthonic/work` | TT |
| `Booking` | `@chthonic/booking` | TT, MarineDeck |
| `Invoice` / `Estimate` | `@chthonic/billing` | All |
| `Customer` | `@chthonic/parties` | All |
| `Vehicle` | TT (asset subtype) | TT |
| `Vessel` | MarineDeck (asset subtype) | MarineDeck |
| `Pet` | PetCare (asset subtype) | PetCare |
| `Forklift` | FlowLift (asset subtype) | FlowLift |
| `Note` | `@chthonic/notes` | All (notes attach files too) |
| `Listing` | `@chthonic/listings` | All |
| `Document` | `@chthonic/documents` | All |

> **PR 11 (F10 Vehicle intake walkaround) consumer note.** RFC 0031's
> original draft proposed a new primary `entity_type='VehicleWalkaround'`.
> That was **superseded** by the files v0.2.0 two-level FK (shipped
> 2026-05-26): walkaround photos keep the **primary** FK on `Job`
> (`entity_type='Job'`, `entity_id=jobId`) and use
> `sub_entity_type='Walkaround'`, `sub_entity_id=walkaroundId` for the
> per-walkaround child concept (RFC 0031 § 12a). This keeps the Job
> Photos page query trivial while surfacing walkaround shots there with
> a "Walkaround" badge — the same pattern as F3 QC evidence. So
> `'VehicleWalkaround'` is **not** a registered primary `entity_type`;
> the recognised TT-side walkaround convention is the `'Walkaround'`
> **sub-entity** string. See [`sub-entity-fk.md`](sub-entity-fk.md).

## Cross-product compatibility

Files can attach to any string. No upgrade is needed when a new product introduces a new asset type — just call `UploadAsync(... entityType: "Forklift", ...)` and the index handles it.

## Related

- [`extension-points.md`](extension-points.md), [`signed-urls.md`](signed-urls.md), [`multipart-upload.md`](multipart-upload.md), [`db-blob-fallback.md`](db-blob-fallback.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 1.
