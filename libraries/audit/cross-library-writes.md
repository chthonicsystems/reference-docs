---
library: audit
version: 0.1.4
related-rfcs: [0006]
last-verified: 2026-05-22
tags: [audit, cross-library, attributes]
summary: Cross-library audit writes — string-variant [AuditParent] attribute pattern.
---

# Cross-library writes

Library A often has an entity that should roll up to a parent type owned by library B. If A references B at compile time, no problem. If A doesn't reference B (typically because of architectural near-cycle avoidance), the **string-variant `[AuditParent]`** attribute solves it.

## Problem

In the platform extraction sequence:

- `@chthonic/parties.CustomerVehicle` should roll up to `Vehicle` for thread-wise audit viewing.
- `Vehicle` lives in `@chthonic/assets`.
- BUT parties extracted before assets in the sequence — and even at steady state, `parties` shouldn't reference `assets`'s subtype hierarchy.

Compile-time `typeof(Vehicle)` is impossible from parties' code.

## Solution — string-variant attribute

```csharp
// In @chthonic/parties:
[AuditCategory("Parties")]
[AuditParent("Vehicle", nameof(VehicleId))]   // ← string, not typeof
public class CustomerVehicle
{
    public int CustomerId { get; set; }
    public int VehicleId { get; set; }
    // ...
}
```

The audit interceptor reads the string at runtime + emits:

```sql
INSERT INTO audit_log
  (entity_type, entity_id, parent_type, parent_id, ...)
VALUES
  ('CustomerVehicle', composite-key, 'Vehicle', 42, ...);
```

The audit viewer sees `parent_type='Vehicle'` and threads under any Vehicle audit row regardless of whether parties knows about Vehicle.

## When to use which variant

| Scenario | Variant |
|---|---|
| Same-library or upstream-library reference is fine | `[AuditParent(typeof(Job), nameof(JobId))]` |
| No compile-time reference desired (architectural decision) | `[AuditParent("Vehicle", nameof(VehicleId))]` |
| Cross-library FK that the platform deliberately keeps nav-prop-free | `[AuditParent("Asset", nameof(AssetId))]` |

## Future swap to typeof

`CustomerVehicle.VehicleId` will eventually become `CustomerAsset.AssetId` after PR 09's class rename completes. At that point, parties may swap to `[AuditParent(typeof(Asset), nameof(AssetId))]` IF the architectural decision allows the reference. Currently a `FIXME(PR 09)` marker in `Chthonic.Audit/Domain/AuditAttributes.cs` flags the future swap consideration.

## How the interceptor handles both

```csharp
// Pseudocode AuditSaveChangesInterceptor
var attr = entityType.GetCustomAttribute<AuditParentAttribute>();
if (attr is not null)
{
    var fkValue = entry.Property(attr.ForeignKeyProperty).CurrentValue;
    string parentTypeName = attr.ParentTypeName ?? attr.ParentType!.Name;
    auditEntry.ParentType = parentTypeName;
    auditEntry.ParentId = fkValue;
}
```

Both constructor variants populate `ParentTypeName` (the string) on the same `AuditParentAttribute` class.

## Related

- [`auditparent-attribute.md`](auditparent-attribute.md) — both variants.
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 6 (cross-library FK-only typing).
- [RFC 0006](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0006-audit-logging.md).
