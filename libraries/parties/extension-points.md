---
library: parties
version: 0.2.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [parties, extension-points]
summary: Extension points — identity adapter, asset attachment, search hooks.
---

# Extension points

Parties exposes a small adapter surface and is otherwise a self-contained CRUD library.

## `PartiesCustomerLinkingAdapter : ICustomerLinkingPort`

The adapter wires parties' `ICustomerLinkingService` into identity's `ICustomerLinkingPort`. Consumer registration:

```csharp
builder.Services.AddScoped<ICustomerLinkingPort, PartiesCustomerLinkingAdapter>();
```

When identity calls `ICustomerLinkingPort.LinkUserToCustomerAsync`, the adapter delegates to parties' `CustomerLinkingService.FindCustomerByMobileAsync` + `LinkAsync`.

## Polymorphic asset attachment

`customer_asset.asset_id` is a FK to `@chthonic/assets`'s `Asset` polymorphic base. Adding a new asset subtype (e.g. when MarineDeck registers `Vessel`) doesn't require any change to parties — the asset_id space stays unified.

When TT's `Vehicle` was renamed in PR 08, parties received a column rename:
```sql
ALTER TABLE customer_asset RENAME COLUMN vehicle_id TO asset_id;
```
…with no entity changes.

## Custom customer fields

Parties' `Customer` entity ships fixed columns (name, email, mobile, address, notes). Custom per-tenant fields go through `@chthonic/views`:

1. Define fields in the views layer with `entity_type = 'Customer'`.
2. Render via `<ScreenSectionsRenderer entityType="Customer" entityId={customerId} />` from `@chthonicsystems/views`.

The library does **not** support a per-product subclass of Customer. Custom data goes through views.

## Hooks for consumer components

```tsx
useCustomers({ systemId, pageSize, search?, ... })
  → { data, total, page, setPage, search, setSearch, loading, refresh }
```

Returns paginated customer search. Used by:
- TT's `/customers` listing page.
- `<CustomerSearchSelect>` typeahead.
- Job/booking creation customer pickers.

## RBAC

Endpoint-level: `[RequiresPermission("page:customers")]` etc. The library ships a simple `RequirePermissionFilter` you can use directly, or rely on the consumer's identity-side filter.

## Adding a search field

To make customers searchable on a new column (e.g. `tax_id`):

1. Add the column to `customer` table via migration.
2. Update `CustomerSearchAsync` to include the new column in the LIKE clause.
3. Add an index if needed.

This is a library change — bump the minor version.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`libraries/identity/customer-auth.md`](../identity/customer-auth.md) — port consumer.
- [`libraries/assets/`](../assets/) — polymorphic FK target.
- [`libraries/views/custom-fields.md`](../views/custom-fields.md) — adding per-tenant Customer fields.
