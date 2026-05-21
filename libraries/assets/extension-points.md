---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, extension-points]
summary: Extension points — RegisterAssetSubtype<T>, AssetSubtypeOptions, AssetPermissionOptions.
---

# Extension points

| Hook | Use |
|---|---|
| `services.RegisterAssetSubtype<T>(opts)` | Register a product-specific subtype (Vehicle, Vessel, Forklift, Pet) |
| `IAssetSubtypeRegistry` | Runtime lookup |
| `AssetSubtypeOptions` | Per-subtype display config |
| `AssetPermissionOptions` | Override RBAC permission names per product |

## Registering a subtype

```csharp
builder.Services.RegisterAssetSubtype<Vehicle>(opts =>
{
    opts.DisplayName = "Vehicle";
    opts.PluralDisplayName = "Vehicles";
    opts.IconName = "car-outline";
    opts.SearchableFields = new[] { "RegistrationNumber", "Make", "Model", "Vin" };
});
```

Multiple registrations are allowed (e.g. a product with `Vessel` AND `Trailer`). The library picks the registration matching the entity's `AssetType` discriminator at runtime.

## AssetPermissionOptions

By default the library expects permission names `page:assets`, `action:create-asset`, etc. Override:

```csharp
builder.Services.Configure<AssetPermissionOptions>(opts =>
{
    opts.PageAssetsPermission = "page:vehicles";          // TT keeps legacy name
    opts.CreateAssetPermission = "action:create-vehicle";
    // ...
});
```

## Custom subtype service

The default `AssetService` handles generic CRUD. A product needing subtype-specific logic (e.g. NHTSA VIN lookup for Vehicle) ships a per-subtype service alongside:

```csharp
// TT
public interface IVehicleService    // wraps IAssetService + adds NHTSA
{
    Task<Vehicle> CreateAsync(VehicleInput input);
    Task<VehicleDecodeResult> DecodeVinAsync(string vin);
}

builder.Services.AddScoped<IVehicleService, VehicleService>();
```

## Migrations

When a product registers a new subtype, add a migration that creates the subtype's columns on the `asset` table:

```csharp
public partial class AddVesselSubtype : Migration
{
    protected override void Up(MigrationBuilder mb)
    {
        mb.AddColumn<decimal>("length_m", "asset", nullable: true);
        mb.AddColumn<string>("hull_type", "asset", nullable: true, maxLength: 50);
        mb.AddColumn<string>("registration_country", "asset", nullable: true, maxLength: 50);
    }
    protected override void Down(MigrationBuilder mb)
    {
        mb.DropColumn("length_m", "asset");
        mb.DropColumn("hull_type", "asset");
        mb.DropColumn("registration_country", "asset");
    }
}
```

## Cross-library FK references

Other libraries (`@chthonic/work`, `@chthonic/booking`, `@chthonic/billing`) reference `Asset` by FK + cast at the call site. They MUST NOT add subtype-specific nav properties. See [`cross-library-fk-only.md`](cross-library-fk-only.md).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`tph-polymorphism.md`](tph-polymorphism.md), [`subtype-registry.md`](subtype-registry.md), [`cross-library-fk-only.md`](cross-library-fk-only.md).
