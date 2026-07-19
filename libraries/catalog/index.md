---
library: catalog
package-nuget: Chthonic.Catalog
package-npm: '@chthonicsystems/catalog'
version: 0.2.1
related-rfcs: [0021, 0034]
related-libs: [tenant, audit, inventory]
last-verified: 2026-07-20
tags: [core-domain, catalog, services, products, service-packages]
summary: Service & Product catalog spine — vertical-agnostic "what does this tenant sell". v0.2.x adds ServicePackage bundles (job templates / repair packages).
---

# `@chthonicsystems/catalog` / `Chthonic.Catalog`

The vertical-agnostic catalog spine. Owns four entities: `Service`, `ServiceItem`, `Product`, `ProductVariant`. Time slots and off-days defer to `@chthonic/booking`.

## Purpose

A tenant's "menu" — the services they offer (oil change, hull cleaning, vaccination) plus the products they sell (parts, supplies). The catalog is the lowest-common-denominator across products:

- TT — motorbike services, motorcycle parts.
- MarineDeck — slip-cleaning, hull inspection; chandlery products.
- FlowLift — forklift servicing, replacement parts.
- PetCare — vaccinations, exam services; medications.

Same shape; different content per tenant.

## Public surface

### .NET

| Type | File | Role |
|---|---|---|
| `ICatalogServices` / `CatalogServices` | `src/Chthonic.Catalog/Services/CatalogServices.cs` | CRUD over Service + Product |
| `IDbContextProvider` (port) | `src/Chthonic.Catalog/Extensions/IDbContextProvider.cs` | Consumer-supplied DbContext bridge |
| `MapChthonicCatalogEndpoints` | `src/Chthonic.Catalog/Endpoints/CatalogEndpoints.cs` | `/api/services/*`, `/api/products/*` |
| `Service`, `ServiceItem`, `Product`, `ProductVariant` | `src/Chthonic.Catalog/Domain/*.cs` | Entities |
| `ServicePackage`, `ServicePackageItem` | `src/Chthonic.Catalog/Domain/*.cs` | **v0.2.0** bundle entities (RFC 0034) — see [`service-packages.md`](service-packages.md) |
| `IServicePackageService` / `ServicePackageService` | `src/Chthonic.Catalog/Services/ServicePackageService.cs` | **v0.2.0** package CRUD + `ComputeTotalAsync` |
| `MapChthonicServicePackageEndpoints` | `src/Chthonic.Catalog/Endpoints/ServicePackageEndpoints.cs` | **v0.2.0** `/api/service-packages/*` via a **separate** mapper (RFC 0034 § 12a) |
| `services.AddChthonicCatalog()` | `src/Chthonic.Catalog/ServiceCollectionExtensions.cs` | DI entry point (also registers `IServicePackageService` from v0.2.0) |

### npm

| Export | Role |
|---|---|
| `useServices`, `useProducts` hooks | Paginated catalog reads |
| `<ServiceSearchSelect>`, `<ProductSearchSelect>` | Typeahead pickers |
| `<ServicePackagePicker>` | **v0.2.x** package picker (`onApply` callback) |
| `servicePackageService` | **v0.2.x** HTTP service factory for package CRUD |
| Types | `Service`, `ServiceItem`, `Product`, `ProductVariant`, `ServicePackage`, `ServicePackageItem` |

`CATALOG_PACKAGE_VERSION === '0.2.1'`.

## Schema

```
service
  service_id      int PK
  system_id       int
  name            varchar(200)
  description     text?
  display_order   int
  is_active       bool
  created_at      datetime
  index ix_service_system (system_id)

service_item
  service_item_id int PK
  service_id      int FK
  name            varchar(200)
  description     text?
  cost            decimal(10,2)
  display_order   int
  index ix_service_item_service (service_id)

product
  product_id      int PK
  system_id       int
  name            varchar(200)
  description     text?
  display_order   int
  is_active       bool
  index ix_product_system (system_id)

product_variant
  product_variant_id int PK
  product_id         int FK
  name               varchar(200)
  description        text?
  sku                varchar(100)?
  barcode            varchar(100)?
  price              decimal(10,2)
  is_active          bool
  display_order      int
  index ix_variant_product (product_id)
```

**Service has no cost** — service cost is calculated as the sum of its `service_item.cost` values. Itemized pricing only.

### v0.2.0 schema delta — ServicePackage (RFC 0034)

```
service_package
  service_package_id  int PK
  system_id           int
  service_id          int FK?          (optional owning Service)
  name                varchar(255)
  description         text?
  is_active           bool
  display_order       int
  created_at          datetime
  updated_at          datetime

service_package_item
  service_package_item_id int PK
  service_package_id      int FK
  service_item_id         int FK?       (XOR product_variant_id)
  product_variant_id      int FK?       (XOR service_item_id)
  quantity                decimal(10,2)
  display_order           int
  -- consumer-side CHECK enforces the ServiceItemId XOR ProductVariantId invariant
```

Pricing is **sum-of-components** (no package price). The library migration is an empty placeholder; the consumer owns the real `CREATE TABLE` + `CHECK` (coexistence pattern). Apply-to-a-work-unit + provenance stay **consumer-side**. Full deep-ref: [`service-packages.md`](service-packages.md).

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | `system_id` scoping |
| `@chthonic/audit` | `[AuditCategory("Catalog")]` |

## Extension points

| Hook | Use |
|---|---|
| `IDbContextProvider` (port) | Consumer-supplied DbContext bridge — registered before `AddChthonicCatalog` |
| `services.AddChthonicCatalog()` | DI entry point |
| `MapChthonicCatalogEndpoints()` | Generic CRUD endpoints — sister-product ready |
| `MapChthonicServicePackageEndpoints()` | **v0.2.0** ServicePackage CRUD — a **separate** mapper so consumers mount package endpoints under their own feature gate without mounting `CatalogEndpoints` (RFC 0034 § 12a) |

NB per PR 11.5: TT keeps its own `api/Features/{Services,Products}/` because of TT-specific JobField auto-wiring + `LinkedFieldName` enrichment. MarineDeck / FlowLift / PetCare mount the library's generic endpoints.

## Consuming this library

```csharp
using Chthonic.Catalog;

// IDbContextProvider adapter — bridges to your consumer DbContext
builder.Services.AddScoped<IDbContextProvider, MyDbContextProvider>();
builder.Services.AddChthonicCatalog();
app.MapChthonicCatalogEndpoints();   // sister-product
```

```tsx
import { ServiceSearchSelect, ProductSearchSelect, useServices } from '@chthonicsystems/catalog';

<ServiceSearchSelect systemId={systemId} onSelect={(s) => ...} />
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`service-and-product.md`](service-and-product.md), [`serviceitem-fields.md`](serviceitem-fields.md), [`productvariant-pricing.md`](productvariant-pricing.md).
- [`service-packages.md`](service-packages.md) — **v0.2.0** ServicePackage bundles (job templates / repair packages, RFC 0034).
- [`@chthonic/inventory`](../inventory/index.md) — stock-on-hand for the `ProductVariant`s a package/line-item consumes (RFC 0030).
- Library repo: [chthonicsystems/catalog](https://github.com/chthonicsystems/catalog).
- [RFC 0021](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0021-catalog.md), [RFC 0034](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0034-job-templates.md).
