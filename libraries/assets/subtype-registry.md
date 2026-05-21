---
library: assets
version: 0.1.0
related-rfcs: [0008]
last-verified: 2026-05-22
tags: [assets, subtype-registry]
summary: IAssetSubtypeRegistry — runtime lookup of registered subtypes for UI + dispatch.
---

# Subtype registry

`IAssetSubtypeRegistry` is the runtime catalog of registered asset subtypes. Each product registers its subtype(s) at startup; UI components + dispatch logic read from the registry.

## Interface

```csharp
public interface IAssetSubtypeRegistry
{
    void Register<T>(AssetSubtypeOptions opts) where T : Asset;
    AssetSubtypeOptions? Get(string assetTypeName);
    IReadOnlyDictionary<string, AssetSubtypeOptions> All { get; }
}
```

## AssetSubtypeOptions

```csharp
public class AssetSubtypeOptions
{
    public required string DisplayName { get; init; }      // "Vehicle"
    public string? PluralDisplayName { get; init; }         // "Vehicles"
    public string? IconName { get; init; }                  // "car-outline" (ionicon)
    public string[] SearchableFields { get; init; } = [];   // ["RegistrationNumber", "Make", "Vin"]
    public string[] DisplayFields { get; init; } = [];      // for list-view summary
}
```

Add fields to the options class as needed via minor version bumps.

## Use cases

### UI typeahead

```tsx
import { useAssetSubtypes } from '@chthonicsystems/assets';

function AssetSearchSelect() {
  const subtypes = useAssetSubtypes();   // hook reads from server-rendered config
  return (
    <select>
      {Object.entries(subtypes).map(([key, opts]) => (
        <option key={key} value={key}>{opts.displayName}</option>
      ))}
    </select>
  );
}
```

### Server-side dispatch

```csharp
public class AssetEndpoints
{
    public async Task<IResult> Create(CreateAssetRequest req)
    {
        var opts = _registry.Get(req.AssetType);
        if (opts is null) return Results.BadRequest(...);
        // Use opts.DisplayName in error messages, etc.
    }
}
```

## Registration ordering

Multiple products in one DB shouldn't happen, but if it did:

```csharp
builder.Services.RegisterAssetSubtype<Vehicle>(...);
builder.Services.RegisterAssetSubtype<Trailer>(...);   // same product, two subtypes
```

Both registrations happen in startup order. `IAssetSubtypeRegistry.All` returns both.

## Lifetime

`IAssetSubtypeRegistry` is registered as singleton. Registrations happen once at app startup; no runtime add/remove.

## Related

- [`tph-polymorphism.md`](tph-polymorphism.md), [`extension-points.md`](extension-points.md).
- [RFC 0008](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0008-asset-entity-generalization.md).
