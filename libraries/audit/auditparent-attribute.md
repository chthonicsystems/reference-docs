---
library: audit
version: 0.1.4
related-rfcs: [0006]
last-verified: 2026-05-22
tags: [audit, attributes, rollup]
summary: [AuditParent] attribute — child entity changes roll up to a parent for thread-wise viewing.
---

# `[AuditParent]` attribute

A child entity (`JobMechanic`, `JobApproval`, `CustomerVehicle`, `JobPartsInstalled`) often makes more sense in audit history under its parent (`Job`, `Customer`). `[AuditParent]` declares that rollup.

## Two constructor variants

### Typed (preferred when same-library reference is fine)

```csharp
[AuditCategory("Work")]
[AuditParent(typeof(Job), nameof(JobId))]
public class JobMechanic
{
    public int JobMechanicId { get; set; }
    public int JobId { get; set; }
    public int UserId { get; set; }
    // ...
}
```

`typeof(Job)` requires `@chthonic/work` reference at compile time. Use within a library or when the parent lives in a same-tier dependency.

### String (cross-library FK without reference)

```csharp
// In @chthonic/parties:
[AuditCategory("Parties")]
[AuditParent("Vehicle", nameof(VehicleId))]
public class CustomerVehicle
{
    public int CustomerId { get; set; }
    public int VehicleId { get; set; }
    public string Role { get; set; } = "owner";
    // ...
}
```

`"Vehicle"` is a string. Parties doesn't reference `@chthonic/assets`. Audit interceptor reads the string at runtime + emits `parent_type='Vehicle'`, `parent_id=VehicleId`.

The string variant was added in `Chthonic.Audit@0.1.4` to support the parties → Vehicle rollup (see PR 04b extraction-sequence note). Future cross-library FK rollups follow the same pattern.

## Audit row shape

```sql
INSERT INTO audit_log
  (category, action, entity_type, entity_id, parent_type, parent_id, ...)
VALUES
  ('Work', 'jobmechanic.added', 'JobMechanic', 42, 'Job', 17, ...);
```

The audit viewer's "view by entity" feature can either:
- Filter by `entity_type='JobMechanic' AND entity_id=42` (just this row).
- Filter by `parent_type='Job' AND parent_id=17` (this row + all sibling JobMechanic / JobApproval / etc. changes for Job 17).

## Action naming

Convention: `<entity_type_lowercase>.<verb>`.

| Verb | Trigger |
|---|---|
| `created` / `added` | EF `EntityState.Added` |
| `updated` | EF `EntityState.Modified` (with at least one tracked column changed) |
| `deleted` | EF `EntityState.Deleted` |

The interceptor auto-derives action from `EntityState`. Manual overrides via `[AuditAction("custom-name")]` (planned; not yet shipping).

## Multiple parents

A child entity has at most ONE `[AuditParent]` attribute. Multiple parents (e.g. `JobMechanic` rolling up to both `Job` AND `User`) → only the declared one wins.

If you need both, emit a manual second audit row in the service layer:

```csharp
await _audit.LogAsync(new AuditEntry
{
    EntityType = "JobMechanic", EntityId = jobMechanicId,
    ParentType = "User", ParentId = userId,
    Category = "Work", Action = "jobmechanic.added",
    // ...
});
```

## Related

- [`architecture.md`](architecture.md) — `AuditSaveChangesInterceptor` reads attributes.
- [`cross-library-writes.md`](cross-library-writes.md) — string-variant constructor in detail.
- [`extension-points.md`](extension-points.md).
