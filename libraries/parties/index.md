---
library: parties
package-nuget: Chthonic.Parties
package-npm: '@chthonicsystems/parties'
version: 0.2.0
related-rfcs: [0004]
related-libs: [identity, tenant, audit, assets]
last-verified: 2026-05-22
tags: [foundational, customers, addresses, mobile-verification]
summary: Customers + addresses + contacts + customer-asset linking.
---

# `@chthonicsystems/parties` / `Chthonic.Parties`

Owns the `Customer` entity (the human or business a tenant serves) plus customer-asset linking, customer-user linking (used by `@chthonic/identity` customer-auth), and the `<CustomerSearchSelect>` UI primitive.

## Purpose

A `Customer` is **anyone a tenant serves** — not anyone authorised to use the app (those are `User` rows in identity). A customer can have:
- Multiple assets (vehicles / vessels / pets / forklifts), via `customer_asset` polymorphic-FK join
- An optional linked `User` record (from `@chthonic/identity` customer-auth)
- Address + contact details

## Public surface

### .NET

**Package:** `Chthonic.Parties` (NuGet, v0.2.0)

| Type | File | Role |
|---|---|---|
| `ICustomerService` / `CustomerService` | `src/Chthonic.Parties/CustomerService.cs` | Customer CRUD + search |
| `ICustomerLinkingService` / `CustomerLinkingService` | `src/Chthonic.Parties/CustomerLinkingService.cs` | Match user mobile → customer + link |
| `PartiesCustomerLinkingAdapter` | `src/Chthonic.Parties/PartiesCustomerLinkingAdapter.cs` | Adapter for `@chthonic/identity`'s `ICustomerLinkingPort` |
| `MapCustomerEndpoints` | `src/Chthonic.Parties/CustomerEndpoints.cs` | `/api/customers/*` |
| `CustomerDtos` | `src/Chthonic.Parties/CustomerDtos.cs` | Request / response shapes |
| `CustomerServiceException` | `src/Chthonic.Parties/CustomerServiceException.cs` | Domain exception |
| `services.AddChthonicParties()` | `src/Chthonic.Parties/ServiceCollectionExtensions.cs` | DI entry point |

**Domain entities:**
- `Customer` — the customer record
- `CustomerAsset` — `(customer_id, asset_id, role)` polymorphic-FK join (asset_id refers to `assets.Asset` base; consumers cast to their subtype)

### npm

**Package:** `@chthonicsystems/parties` (npm, v0.2.0)

| Export | File | Role |
|---|---|---|
| `useCustomers(opts)` | `npm/src/useCustomers.ts` | Hook for paginated customer search |
| `<CustomerSearchSelect>` | `npm/src/CustomerSearchSelect.tsx` | Typeahead selector with create-inline |
| Types | `npm/src/types.ts` | `Customer`, `CustomerInput`, etc. |

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | `system_id` scoping |
| `@chthonic/audit` | Audit writes on customer create/update/delete |
| `@chthonic/identity` (port `ICustomerLinkingPort`) | Wired backwards — parties provides the adapter that identity consumes |
| `@chthonic/assets` | `customer_asset.asset_id` references `assets.Asset` |

## Extension points

Parties exposes one cross-library adapter:

| Adapter | Role |
|---|---|
| `PartiesCustomerLinkingAdapter : ICustomerLinkingPort` | Implements the identity port. Consumer registers in DI: `services.AddScoped<ICustomerLinkingPort, PartiesCustomerLinkingAdapter>();` |

## Consuming this library

```csharp
// File: api/Program.cs
using Chthonic.Parties;

builder.Services.AddChthonicParties();

// Adapter for identity port
builder.Services.AddScoped<ICustomerLinkingPort, PartiesCustomerLinkingAdapter>();

var app = builder.Build();
app.MapCustomerEndpoints();
```

```tsx
// File: web/src/pages/CreateJobPage.tsx
import { CustomerSearchSelect } from '@chthonicsystems/parties';

<CustomerSearchSelect
  systemId={systemId}
  onSelect={(customer) => setForm({ ...form, customerId: customer.id })}
  allowCreate
/>
```

Full walkthrough in [`consumption.md`](consumption.md).

## Related

- [`architecture.md`](architecture.md) — Customer + CustomerAsset schema.
- [`consumption.md`](consumption.md) — full integration.
- [`extension-points.md`](extension-points.md) — identity adapter, asset-attachment.
- [`customers.md`](customers.md) — customer CRUD + search + linking.
- [`addresses.md`](addresses.md) — address fields on Customer.
- [`mobile-verification.md`](mobile-verification.md) — how customer auth links to a customer record.
- Library repo: [chthonicsystems/parties](https://github.com/chthonicsystems/parties).
- Governing RFC: [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md).
