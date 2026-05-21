---
library: notes
version: 0.1.0
related-rfcs: [0011]
last-verified: 2026-05-22
tags: [notes, polymorphic-fk]
summary: Polymorphic attachment — note.entity_type / entity_id attaches notes to any consumer entity.
---

# Polymorphic attachment

Same pattern as `@chthonic/files`. `note.(entity_type, entity_id)` lets any library / any consumer attach notes to any entity without a FK constraint.

## Schema

```sql
CREATE TABLE note (
    note_id INT PRIMARY KEY AUTO_INCREMENT,
    system_id INT NOT NULL,
    entity_type VARCHAR(50) NOT NULL,    -- 'Job', 'Customer', 'Vehicle', 'Vessel', 'Pet', ...
    entity_id INT NOT NULL,
    body TEXT NOT NULL,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    parent_note_id INT NULL,
    created_by INT NOT NULL,
    created_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    INDEX ix_note_entity (entity_type, entity_id),
    INDEX ix_note_system (system_id)
);
```

## Cross-product strings

| entity_type | Owning library |
|---|---|
| `Job` | `@chthonic/work` |
| `Customer` | `@chthonic/parties` |
| `Booking` | `@chthonic/booking` |
| `Invoice`, `Estimate` | `@chthonic/billing` |
| `Vehicle` | TT |
| `Vessel` | MarineDeck |
| `Forklift` | FlowLift |
| `Pet` | PetCare |
| `Asset` | `@chthonic/assets` (as base; consumers usually pass the subtype name) |

## Orphan handling

When the parent entity is deleted, the library doesn't auto-cleanup notes. Consumer's delete service calls:

```csharp
await _notes.DeleteByEntityAsync("Job", jobId);
```

…or runs a periodic orphan-cleanup job similar to the files library.

## Related

- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 1.
- [`libraries/files/polymorphic-fk.md`](../files/polymorphic-fk.md) — sibling pattern.
