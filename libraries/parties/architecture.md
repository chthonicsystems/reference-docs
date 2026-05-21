---
library: parties
version: 0.2.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [parties, architecture, schema]
summary: Customer + CustomerAsset entities, schema, services.
---

# Architecture

## File layout

```
src/Chthonic.Parties/
├── Authorization/RequirePermissionFilter.cs   # endpoint-level RBAC
├── Common/CommonResponses.cs
├── Configuration/
│   ├── CustomerConfiguration.cs               # Customer EF config
│   └── CustomerAssetConfiguration.cs          # CustomerAsset join config
├── Domain/
│   ├── Customer.cs
│   └── CustomerAsset.cs
├── CustomerEndpoints.cs                       # /api/customers/*
├── CustomerService.cs                         # ICustomerService + CustomerService
├── CustomerLinkingService.cs                  # mobile → customer matching
├── CustomerDtos.cs                            # request/response shapes
├── CustomerServiceException.cs
├── ICustomerLinkingService.cs
├── ICustomerService.cs
├── PartiesCustomerLinkingAdapter.cs           # ICustomerLinkingPort adapter (identity)
├── PartiesModuleMarker.cs
└── ServiceCollectionExtensions.cs
```

## Schema

```
customer
  customer_id          int PK
  system_id            int FK → system
  user_id              int FK → users (nullable; populated when customer-auth links)
  first_name           varchar
  last_name            varchar?
  business_name        varchar?
  email                varchar?
  mobile               varchar?
  phone                varchar?
  address_line_1       varchar?
  address_line_2       varchar?
  city                 varchar?
  state                varchar?
  postal_code          varchar?
  country              varchar?  (ISO-3166-alpha-2 or human name)
  notes                text?
  created_at           datetime
  deleted_at           datetime?  (soft delete)

  index ix_customer_system (system_id)
  index ix_customer_mobile (system_id, mobile)
  index ix_customer_email  (system_id, email)
  unique ix_customer_user  (system_id, user_id) where user_id is not null

customer_asset
  customer_id          int  FK → customer
  asset_id             int  FK → asset (assets library, polymorphic base)
  role                 enum 'owner', 'driver', 'beneficiary', ...
  created_at           datetime

  PK (customer_id, asset_id)
```

`customer.user_id` is FK-only (no nav) per [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 6 (cross-library FK-only typing). Identity owns `User`; parties just stores the int.

`customer_asset.asset_id` references `assets.asset.asset_id` (the polymorphic base). Consumer products (TT, MarineDeck, etc.) cast to their subtype at the call site:

```csharp
var customerAsset = await _db.CustomerAssets.Include(ca => ca.Asset).FirstAsync(...);
var vehicle = (Vehicle)customerAsset.Asset;   // TT-side cast
```

## Endpoints

```
GET    /api/customers                              # paginated, search-by-name/email/mobile
GET    /api/customers/{id}                         # full record + assets
GET    /api/customers/search?q=...                 # typeahead
POST   /api/customers
PUT    /api/customers/{id}
DELETE /api/customers/{id}                         # soft delete

GET    /api/customers/{id}/assets                  # linked assets
PUT    /api/customers/{id}/assets                  # bulk update links

GET    /api/customers/{id}/jobs                    # via cross-library FK (consumer extends)
GET    /api/customers/stats                        # counts by tier / region
```

Auth: `page:customers`, `action:create-customer`, `action:edit-customer`, `action:delete-customer`.

## CustomerService

Pseudocode of the core methods:

```csharp
public interface ICustomerService
{
    Task<Customer> CreateAsync(int systemId, CustomerInput input);
    Task<Customer> UpdateAsync(int customerId, CustomerInput input);
    Task SoftDeleteAsync(int customerId);
    Task<Customer?> GetAsync(int customerId);
    Task<PagedResult<Customer>> SearchAsync(int systemId, string? query, int page, int pageSize);
    Task<List<CustomerAsset>> GetAssetsAsync(int customerId);
    Task UpdateAssetsAsync(int customerId, List<CustomerAssetInput> assets);
}
```

## CustomerLinkingService

Matches mobile → customer. Used by `PartiesCustomerLinkingAdapter` (which implements identity's `ICustomerLinkingPort`).

```csharp
public interface ICustomerLinkingService
{
    Task<int?> FindCustomerByMobileAsync(int systemId, string mobile);
    Task<bool> LinkAsync(int customerId, int userId);   // sets customer.user_id
    Task<bool> UnlinkAsync(int customerId);
}
```

Matching is exact (E.164 normalised). If a customer registers with mobile not yet on file, the user has no linked customer — the staff create the customer record later, which auto-links via the same adapter.

## Tests

| File | Coverage |
|---|---|
| `CustomerServiceTests` | CRUD + soft delete + search |
| `CustomerLinkingServiceTests` | Mobile match (exact, normalisation, no match) |
| `CustomerEndpointsTests` | Endpoint integration (auth, validation, pagination) |
| `PartiesCustomerLinkingAdapterTests` | Adapter delegates correctly |

## Related

- [`index.md`](index.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`customers.md`](customers.md), [`addresses.md`](addresses.md), [`mobile-verification.md`](mobile-verification.md).
- [`libraries/identity/customer-auth.md`](../identity/customer-auth.md) — counterpart customer-auth flow.
- [`libraries/assets/`](../assets/) — `Asset` polymorphic base + subtype registration.
- [RFC 0004](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0004-multi-tenancy-and-identity.md).
