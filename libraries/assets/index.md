---
library: assets
package-nuget: Chthonic.Assets
package-npm: '@chthonicsystems/assets'
version: 0.1.0
related-rfcs: [0008]
related-libs: [tenant, parties, audit]
last-verified: 2026-05-22
tags: [core-domain, polymorphism, tph, asset-subtype]
summary: Polymorphic Asset root + IAssetSubtypeRegistry + RegisterAssetSubtype<T> for Vehicle/Vessel/Forklift/Pet.
---

# `@chthonicsystems/assets` / `Chthonic.Assets`

The polymorphic root for "the thing a tenant services" — `Asset`. Each consumer product registers a subtype (TT: `Vehicle`, MarineDeck: `Vessel`, FlowLift: `Forklift`, PetCare: `Pet`) via TPH (Table Per Hierarchy).

## Purpose

The platform's biggest cross-product abstraction. Pre-extraction TT had `Vehicle` everywhere; post-extraction every Phase-1 product registers its asset subtype on top of the shared `Asset` base.

## Public surface

### .NET

| Type | File | Role |
|---|---|---|
| `Asset` (abstract) | `src/Chthonic.Assets/Domain/Asset.cs` | Polymorphic base — owner, system_id, asset_type discriminator, registration_number, status |
| `IAssetSubtypeRegistry` | `src/Chthonic.Assets/IAssetSubtypeRegistry.cs` | Lookup registered subtypes |
| `AssetSubtypeOptions` | `src/Chthonic.Assets/AssetSubtypeOptions.cs` | Per-subtype config (display name, icon) |
| `IAssetService` / `AssetService` | `src/Chthonic.Assets/AssetService.cs` | CRUD over Asset base |
| `MapChthonicAssetsEndpoints` | `src/Chthonic.Assets/AssetEndpoints.cs` | `/api/assets/*` (sister-product ready; TT keeps its own Vehicle endpoints) |
| `services.AddChthonicAssets()` + `services.RegisterAssetSubtype<T>(opts)` | `src/Chthonic.Assets/ServiceCollectionExtensions.cs` | DI entry points |
| `ModelBuilderExtensions.ConfigureAssetSubtypes` | (file) | Call inside `OnModelCreating` to wire TPH discriminators |

### npm

| Export | Role |
|---|---|
| Types | `Asset`, `AssetSubtype`, etc. |

## Schema

```
asset
  asset_id            int PK
  system_id           int FK
  asset_type          varchar(50)  TPH discriminator: 'Vehicle', 'Vessel', 'Forklift', 'Pet'
  registration_number varchar(100) (e.g. license plate, hull number)
  status              enum 'active', 'inactive', 'retired'
  created_at          datetime

  index ix_asset_system_type (system_id, asset_type)

# Per-product subtype tables — TPH
vehicle (FK asset_id, make, model, year, color, vin, ...)
vessel (FK asset_id, length_m, hull_type, registration_country, ...)
forklift (FK asset_id, capacity_kg, mast_height_mm, ...)
pet (FK asset_id, species, breed, dob, ...)
```

NB: Per the actual implementation, subtypes use **TPH** (single `asset` table with discriminator + nullable subtype columns). Subtype tables shown above are a logical view; physical layout is one wide `asset` table. See [`tph-polymorphism.md`](tph-polymorphism.md).

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | `system_id` scoping |
| `@chthonic/parties` | `customer_asset.asset_id` references back |
| `@chthonic/audit` | `[AuditCategory("Assets")]` on `Asset` base |

## Extension points

| Hook | Use |
|---|---|
| `services.RegisterAssetSubtype<Vehicle>(opts)` | Each product registers its subtype |
| `IAssetSubtypeRegistry` | Runtime lookup of registered subtypes (e.g. for typeahead ui) |
| `ModelBuilderExtensions.ConfigureAssetSubtypes(modelBuilder)` | Wire TPH discriminators in `OnModelCreating` |

## Consuming this library

```csharp
// File: api/Domain/Vehicle.cs (TT)
public class Vehicle : Asset
{
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? Year { get; set; }
    public string? Vin { get; set; }
    // ...
}
```

```csharp
// File: api/Program.cs (TT)
using Chthonic.Assets;

builder.Services.AddChthonicAssets();
builder.Services.RegisterAssetSubtype<Vehicle>(opts =>
{
    opts.DisplayName = "Vehicle";
    opts.IconName = "car-outline";
});

// In DbContext:
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AssetsModuleMarker).Assembly);
    modelBuilder.ConfigureAssetSubtypes();   // wires TPH discriminator + subtype mappings
}
```

TT keeps its `/api/vehicles/*` endpoints because of TT-specific NHTSA catalog + VIN decode. Sister-products use `MapChthonicAssetsEndpoints` for generic asset CRUD.

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`tph-polymorphism.md`](tph-polymorphism.md), [`subtype-registry.md`](subtype-registry.md), [`cross-library-fk-only.md`](cross-library-fk-only.md).
- Library repo: [chthonicsystems/assets](https://github.com/chthonicsystems/assets).
- [RFC 0008](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0008-asset-entity-generalization.md).
