---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, architecture, tph, schema]
summary: Assets internal structure — TPH discriminator, subtype registry, EF migration.
---

# Architecture

## File layout

```
src/Chthonic.Assets/
├── Domain/Asset.cs                       # abstract polymorphic base
├── IAssetSubtypeRegistry.cs              # registry interface
├── AssetSubtypeOptions.cs                # per-subtype config DTO
├── AssetService.cs / IAssetService.cs    # CRUD service
├── AssetEndpoints.cs                     # /api/assets/*
├── AssetDtos.cs                          # request/response shapes
├── AssetPermissionOptions.cs             # consumer-supplied RBAC permission names
├── Configuration/AssetConfiguration.cs   # EF base configuration (TPH setup)
├── Migrations/                           # ChthonicAssets_0001_Initial
├── AssetsModuleMarker.cs
├── ModelBuilderExtensions.cs             # ConfigureAssetSubtypes() wires TPH
└── ServiceCollectionExtensions.cs
```

## Asset base

```csharp
public abstract class Asset
{
    public int AssetId { get; set; }
    public int SystemId { get; set; }
    public string AssetType { get; set; } = null!;   // discriminator; set by TPH
    public string? RegistrationNumber { get; set; }   // nullable since v0.1.0
    public string Status { get; set; } = "active";    // 'active' | 'inactive' | 'retired'
    public DateTime CreatedAt { get; set; }
}
```

## TPH (Table Per Hierarchy)

Single `asset` table; subtype columns nullable:

```sql
CREATE TABLE asset (
    asset_id INT PRIMARY KEY AUTO_INCREMENT,
    system_id INT NOT NULL,
    asset_type VARCHAR(50) NOT NULL,
    registration_number VARCHAR(100) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL,

    -- Vehicle subtype
    make VARCHAR(100) NULL,
    model VARCHAR(100) NULL,
    year INT NULL,
    color VARCHAR(50) NULL,
    vin VARCHAR(100) NULL,

    -- Vessel subtype (added by MarineDeck)
    length_m DECIMAL(8,2) NULL,
    hull_type VARCHAR(50) NULL,
    registration_country VARCHAR(50) NULL,

    -- ... etc
    INDEX ix_asset_system_type (system_id, asset_type)
);
```

EF Core dispatches reads/writes by `AssetType`. Each product owns the migration that adds its subtype's columns. Cross-product schema risk: column-name collisions between products. Mitigated by:

- Subtype-name prefixing (`vehicle_make` vs `vessel_length_m`) — preferred.
- Or per-product migration that adds + drops columns when the product is the only consumer.

## Subtype registry

```csharp
public interface IAssetSubtypeRegistry
{
    void Register<T>(AssetSubtypeOptions opts) where T : Asset;
    AssetSubtypeOptions? Get(string assetTypeName);
    IReadOnlyDictionary<string, AssetSubtypeOptions> All { get; }
}
```

Populated at startup; consumed at runtime by:
- The asset listing UI (typeahead, filters).
- The `<AssetSearchSelect>` component (icon, display name).

## ModelBuilderExtensions

```csharp
public static class ModelBuilderExtensions
{
    public static ModelBuilder ConfigureAssetSubtypes(this ModelBuilder mb)
    {
        // Read registered subtypes via DI bridge + configure TPH discriminator.
        // Subtype-specific columns come from each subtype's IEntityTypeConfiguration.
        return mb;
    }
}
```

Called inside the consumer's `OnModelCreating` after `ApplyConfigurationsFromAssembly`. Reads `IAssetSubtypeRegistry` (via a static DI-bridge holder set during `AddChthonicAssets`) to know which subtypes exist.

## Tests

| File | Coverage |
|---|---|
| `AssetSubtypeRegistryTests` | Register + lookup + duplicate handling |
| `AssetServiceTests` | CRUD scoped by system_id |
| `ModelBuilderExtensionsTests` | TPH discriminator wired correctly |
| `ServiceCollectionExtensionsTests` | `AddChthonicAssets` + `RegisterAssetSubtype<T>` registration |

## Related

- [`tph-polymorphism.md`](tph-polymorphism.md), [`subtype-registry.md`](subtype-registry.md), [`cross-library-fk-only.md`](cross-library-fk-only.md).
- [RFC 0008](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0008-asset-entity-generalization.md).
