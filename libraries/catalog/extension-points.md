---
library: catalog
version: 0.1.0
related-rfcs: [0021]
last-verified: 2026-05-22
tags: [catalog, extension-points]
summary: Extension points — IDbContextProvider, permission overrides, optional time-slot library.
---

# Extension points

| Hook | Use |
|---|---|
| `IDbContextProvider` (port) | Bridge to consumer DbContext |
| Permission options | Override `action:manage-inventory` permission name per consumer |
| `MapChthonicCatalogEndpoints` | Mount or skip; consumer can ship its own endpoints (TT does) |

## Time slots + off-days

Catalog does NOT own time-slot or off-day data. Per RFC 0021, those defer to `@chthonic/booking`. Catalog stops at "what does this tenant sell"; booking owns "when can a customer book it".

If a consumer needs a tighter integration (e.g. service-specific time slots that aren't booking-driven), wire it on top — e.g. add a `service_time_slot` table in the consumer's domain.

## Service field linkage

`@chthonic/views` exposes `linked_field_name` on entity fields so a `Service` row can have custom field values (per-tenant custom fields). The catalog library does not own this linkage; it's wired in `@chthonic/views`. See [`libraries/views/custom-fields.md`](../views/custom-fields.md).

## Adding a custom catalog entity

If your consumer needs a fifth catalog entity (e.g. `ServiceBundle`):

1. Define it in your consumer's domain.
2. Optionally cross-link to `Service` via FK.
3. Don't extend the catalog library — keep custom catalog entities in the consumer.

This keeps the library's surface stable + cross-product compatible.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`libraries/booking/`](../booking/) — time slots + off-days.
- [`libraries/views/custom-fields.md`](../views/custom-fields.md).
