---
library: parties
version: 0.2.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [parties, customers, crud]
summary: Customer entity — CRUD + search + linking endpoints.
---

# Customers

The `Customer` entity is the human or business a tenant serves. CRUD + search + asset linking + (optional) user linking.

## Endpoints

```
GET    /api/customers                              # paginated; filter+sort
GET    /api/customers/{id}                         # full record + linked assets
GET    /api/customers/search?q=...&limit=20        # typeahead
POST   /api/customers
PUT    /api/customers/{id}
DELETE /api/customers/{id}                         # soft delete (deleted_at)

GET    /api/customers/{id}/assets                  # linked CustomerAsset rows
PUT    /api/customers/{id}/assets                  # bulk update links

GET    /api/customers/{id}/jobs                    # cross-library FK; consumer extends
GET    /api/customers/stats                        # aggregate counts
```

## Request/response shapes

```ts
interface CustomerInput {
  firstName: string;
  lastName?: string;
  businessName?: string;
  email?: string;
  mobile?: string;
  phone?: string;
  addressLine1?: string;
  addressLine2?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
  notes?: string;
}

interface Customer extends CustomerInput {
  id: number;
  systemId: number;
  userId?: number;     // populated when customer-auth links
  createdAt: string;
  deletedAt?: string;
}
```

Either `firstName + lastName` OR `businessName` is required; both are valid (sole-trader scenarios).

## Validation

| Field | Rule |
|---|---|
| `firstName` / `lastName` | Each ≤ 100 chars |
| `businessName` | ≤ 200 chars |
| `email` | Valid format if provided; max 200 chars |
| `mobile` / `phone` | E.164 normalised on save |
| `country` | ISO-3166-alpha-2 (`AU`, `US`) or human name; tolerated either way |
| `postalCode` | ≤ 20 chars |

## Search

`GET /api/customers/search?q=...` searches:
- `first_name + last_name` (concatenated, LIKE)
- `business_name` (LIKE)
- `email` (LIKE)
- `mobile` (LIKE, both raw and E.164 normalised)

Results paginated (default 20). Sorted by relevance (LIKE-prefix matches first).

## Soft delete

`DELETE /api/customers/{id}` sets `deleted_at = now()`. Subsequent `GET` calls return 404; search results exclude rows with non-null `deleted_at`. Restore = clear `deleted_at` (not exposed via API; admin DB action).

## Customer-asset link

`PUT /api/customers/{id}/assets` — bulk update.

Request:

```json
{
  "assets": [
    { "assetId": 42, "role": "owner" },
    { "assetId": 99, "role": "driver" }
  ]
}
```

Response: 204 No Content.

The endpoint diff-applies — existing rows not in the request are deleted, new ones inserted, existing role changes updated.

## Customer-user link

Set automatically by `PartiesCustomerLinkingAdapter` (which implements `ICustomerLinkingPort` for identity). Direct API:

```
POST /api/customers/{id}/link-user
{ "userId": 42 }
```

Sets `customer.user_id = 42`. 409 if already linked. The endpoint is admin-only; the auto-linking flow at customer-auth registration uses the service directly (no HTTP call).

## Frontend hook

```tsx
import { useCustomers } from '@chthonicsystems/parties';

const { data, total, page, setPage, search, setSearch, loading } = useCustomers({
  systemId,
  pageSize: 20,
});
```

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`addresses.md`](addresses.md), [`mobile-verification.md`](mobile-verification.md).
- [`libraries/identity/customer-auth.md`](../identity/customer-auth.md).
