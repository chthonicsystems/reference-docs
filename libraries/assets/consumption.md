---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, consumption]
summary: Code-level integration walkthrough — registering a subtype.
---

# Consuming `@chthonic/assets`

## 1. Add package reference

```xml
<PackageReference Include="Chthonic.Assets" Version="0.1.0" />
```

## 2. Define your subtype

```csharp
// File: api/Domain/Vehicle.cs (TT example)
using Chthonic.Assets.Domain;

public class Vehicle : Asset
{
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? Year { get; set; }
    public string? Color { get; set; }
    public string? Vin { get; set; }
}
```

```csharp
// MarineDeck would have:
public class Vessel : Asset
{
    public decimal? LengthM { get; set; }
    public string? HullType { get; set; }
    public string? RegistrationCountry { get; set; }
}
```

## 3. Configure the subtype's columns

```csharp
// File: api/Configuration/VehicleConfiguration.cs
public class VehicleConfiguration : IEntityTypeConfiguration<Vehicle>
{
    public void Configure(EntityTypeBuilder<Vehicle> b)
    {
        // No table mapping — TPH inherits from Asset's mapping.
        b.Property(v => v.Make).HasMaxLength(100);
        b.Property(v => v.Model).HasMaxLength(100);
        b.Property(v => v.Vin).HasMaxLength(100);
    }
}
```

## 4. Register the subtype + configure DI

```csharp
// File: api/Program.cs
using Chthonic.Assets;

builder.Services.AddChthonicAssets();

builder.Services.RegisterAssetSubtype<Vehicle>(opts =>
{
    opts.DisplayName = "Vehicle";
    opts.IconName = "car-outline";
});
```

## 5. Wire TPH discriminator in DbContext

```csharp
// File: api/Data/TorqueTechDbContext.cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    base.OnModelCreating(modelBuilder);

    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AssetsModuleMarker).Assembly);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(YourProjectMarker).Assembly);

    modelBuilder.ConfigureAssetSubtypes();   // wires discriminator + TPH
}
```

The DbContext now resolves `Asset` reads by discriminator — `_db.Set<Vehicle>().ToList()` gives only Vehicles; `_db.Set<Asset>().ToList()` gives all subtypes (rare).

## 6. CRUD

```csharp
// Direct via DbContext
var vehicle = new Vehicle
{
    SystemId = systemId,
    AssetType = "Vehicle",   // matches discriminator
    RegistrationNumber = "ABC-123",
    Make = "Honda",
    Model = "Civic",
    Year = 2024,
};
_db.Vehicles.Add(vehicle);
await _db.SaveChangesAsync();
```

Or via `IAssetService`:

```csharp
var asset = await _assets.CreateAsync(new CreateAssetRequest
{
    SystemId = systemId,
    AssetType = "Vehicle",
    Subtype = vehicleData,   // serialised subtype-specific fields
});
```

## 7. Endpoints

TT keeps `/api/vehicles/*` endpoints because of vehicle-specific logic (NHTSA decode, motorbike service catalog mapping, `make_country` filter). Sister-products mount the library's generic endpoints:

```csharp
// MarineDeck:
app.MapChthonicAssetsEndpoints();   // /api/assets/* generic
```

## 8. Cross-library use (FK-only typing)

Other libraries reference `Asset` by FK + cast at call site:

```csharp
// In @chthonic/work
public class Job
{
    public int AssetId { get; set; }                   // FK to assets.Asset
    public Asset Asset { get; set; } = null!;          // polymorphic-base nav
}

// In TT:
var job = await _db.Jobs.Include(j => j.Asset).FirstAsync(...);
var vehicle = (Vehicle)job.Asset;                       // downcast
```

## 9. Verification

- [ ] `_db.Vehicles.ToList()` returns only Vehicles.
- [ ] `_db.Set<Asset>().ToList()` returns all subtypes.
- [ ] TPH discriminator column (`asset_type`) populates correctly on insert.
- [ ] Cross-library FK reads (Job.Asset) cast to Vehicle without exception.
- [ ] `IAssetSubtypeRegistry.All` lists registered subtypes.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`tph-polymorphism.md`](tph-polymorphism.md), [`subtype-registry.md`](subtype-registry.md), [`cross-library-fk-only.md`](cross-library-fk-only.md).
