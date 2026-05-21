---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, tph, polymorphism]
summary: TPH (Table Per Hierarchy) — single asset table with discriminator + nullable subtype columns.
---

# TPH polymorphism

`Asset` uses **TPH** (Table Per Hierarchy) — a single `asset` table holds rows of all subtypes; the `asset_type` discriminator column tells EF which subtype each row belongs to.

## Why TPH (not TPT or TPC)

Considered alternatives:

| Strategy | Pros | Cons |
|---|---|---|
| **TPH** (chosen) | One table = one query, simple FK targets, fast joins | Wide table; nullable subtype columns |
| TPT (Table Per Type) | Normalized schema | 2 queries per Asset list (base + subtype join); FK targets ambiguous |
| TPC (Table Per Concrete) | Each product has independent table | Cross-library FK from Job.Asset becomes impossible |

For the platform, **`Job.Asset` references must work across products**. TPC breaks this. TPT's two-query overhead is unnecessary. TPH wins.

## Schema

```sql
CREATE TABLE asset (
    asset_id INT PRIMARY KEY AUTO_INCREMENT,
    system_id INT NOT NULL,
    asset_type VARCHAR(50) NOT NULL,         -- discriminator
    registration_number VARCHAR(100) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL,

    -- Nullable per-subtype columns. Each product owns its subtype's columns
    -- via a migration that adds them to this table.
    make VARCHAR(100) NULL,                  -- Vehicle
    model VARCHAR(100) NULL,                 -- Vehicle
    year INT NULL,                            -- Vehicle
    vin VARCHAR(100) NULL,                    -- Vehicle

    length_m DECIMAL(8,2) NULL,               -- Vessel (added by MarineDeck)
    hull_type VARCHAR(50) NULL,               -- Vessel

    -- ... etc

    INDEX ix_asset_system_type (system_id, asset_type)
);
```

## EF discriminator

`ConfigureAssetSubtypes()` sets up the discriminator:

```csharp
modelBuilder.Entity<Asset>()
    .HasDiscriminator(a => a.AssetType)
    .HasValue<Vehicle>("Vehicle")
    .HasValue<Vessel>("Vessel")
    // ... per registered subtype
    ;
```

Reads:

```csharp
_db.Set<Vehicle>().ToList();    // SELECT * FROM asset WHERE asset_type = 'Vehicle'
_db.Set<Asset>().ToList();      // SELECT * FROM asset (all subtypes)
```

## Cross-product schema collisions

Two products both adding `make`-named column to `asset` would collide. Avoidance:

1. Each product runs only its own subset of subtypes.
2. Subtypes live in product-specific repos (one product's migration doesn't affect another's DB).
3. Phase-1 products are independent forks; cross-collision happens only if a deployment hosts multiple products in the same DB (rare).

If a future use case needs N subtypes in one DB, adopt prefixed columns (`vehicle_make`, `vessel_length_m`) at that point.

## Performance

Index `(system_id, asset_type)` is fast for "all assets of type X for tenant Y" — the most common query. Subtype-specific filters (e.g. `WHERE make = 'Honda'`) hit the discriminator-filtered subset.

## Related

- [`subtype-registry.md`](subtype-registry.md), [`cross-library-fk-only.md`](cross-library-fk-only.md).
- [RFC 0008](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0008-asset-entity-generalization.md).
