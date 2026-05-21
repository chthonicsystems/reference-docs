---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, polymorphic-fk, entity-discriminator]
summary: entity_type discriminator + (entity_type, entity_id) polymorphic FK on entity_field_value.
---

# Entity-type discriminator

`SystemView`, `SystemEntityField`, and `EntityFieldValue` carry an `entity_type` discriminator string. The library doesn't know what entity types exist; consumers freely use `'Job'`, `'Customer'`, `'Vessel'`, `'Pet'`, `'Forklift'` as values.

## Why per-entity views

A tenant might want different field configurations per entity type:

- Jobs: oil level, parts cost, mechanic assignment.
- Customers: tier, discount %, communication preference.
- Vehicles (TT-specific): VIN, engine size.

Each entity type has its own `SystemView` rows scoped via `entity_type` column.

## Schema rename history

Pre-extraction TT had `system_job_field*` (job-specific). PR 11 renamed:

```
system_job_field*       → system_entity_field*
job_field_value         → entity_field_value
```

…and added `entity_type` discriminator + made the FK polymorphic. The library `0001_Initial` migration runs an `ALTER TABLE … RENAME TO` for consumers upgrading from pre-extraction state.

## Polymorphic FK

```sql
CREATE TABLE entity_field_value (
    entity_field_value_id INT PRIMARY KEY AUTO_INCREMENT,
    entity_field_id INT NOT NULL,
    entity_type VARCHAR(50) NOT NULL,    -- 'Job', 'Customer', 'Vessel', ...
    entity_id INT NOT NULL,
    value TEXT NULL,
    INDEX ix_efv_entity (entity_type, entity_id)
);
```

Same pattern as `@chthonic/notes` and `@chthonic/files`. No FK constraint to the consumer's tables; orphan handling is the consumer's responsibility (or per-entity `DeleteByEntityAsync`).

## Cross-product agnosticism

A new entity type doesn't require library changes. Just call:

```csharp
await _fields.SetValueAsync(systemId, entityType: "Vessel", entityId: vesselId, fieldId: f, value: "...");
```

…and the library writes / reads via discriminator.

## Related

- [`custom-fields.md`](custom-fields.md), [`screen-sections-renderer.md`](screen-sections-renderer.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 1 (polymorphic FK).
