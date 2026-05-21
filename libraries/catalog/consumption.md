---
library: catalog
version: 0.1.0
related-rfcs: [0021]
last-verified: 2026-05-22
tags: [catalog, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/catalog`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Catalog" Version="0.1.0" />
```

```json
"@chthonicsystems/catalog": "0.1.0"
```

## 2. Implement IDbContextProvider

```csharp
public class MyDbContextProvider : IDbContextProvider
{
    private readonly TorqueTechDbContext _db;
    public MyDbContextProvider(TorqueTechDbContext db) => _db = db;
    public DbContext GetDbContext() => _db;
}

builder.Services.AddScoped<IDbContextProvider, MyDbContextProvider>();
builder.Services.AddChthonicCatalog();
```

## 3. EF migration registration

```csharp
modelBuilder.ApplyConfigurationsFromAssembly(typeof(CatalogModuleMarker).Assembly);
```

Or, if shipping idempotently against existing TT schema, insert `__EFMigrationsHistory` row.

## 4. Endpoints

```csharp
// Sister-products mount the generic endpoints:
app.MapChthonicCatalogEndpoints();

// TT keeps its own api/Features/{Services,Products}/ endpoints because of
// JobField auto-wiring + LinkedFieldName enrichment specific to TT.
```

## 5. Frontend — typeahead

```tsx
import { ServiceSearchSelect, ProductSearchSelect, useServices } from '@chthonicsystems/catalog';

<ServiceSearchSelect
  systemId={systemId}
  onSelect={(service) => setForm({ ...form, serviceId: service.id })}
  allowCreate
/>
```

## 6. Verification

- [ ] `GET /api/services` returns the seed catalog.
- [ ] Create a service + add 3 items → service total cost = sum of items.
- [ ] Create a product with 3 variants → SKU + barcode searchable.
- [ ] Audit rows written on every CRUD operation.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`service-and-product.md`](service-and-product.md), [`serviceitem-fields.md`](serviceitem-fields.md), [`productvariant-pricing.md`](productvariant-pricing.md).
