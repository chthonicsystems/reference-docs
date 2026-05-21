---
library: parties
version: 0.2.0
related-rfcs: [0004]
last-verified: 2026-05-22
tags: [parties, addresses]
summary: Customer address fields + country normalisation + downstream consumers.
---

# Addresses

The `Customer` entity ships address fields inline (no separate `address` table). One address per customer; multiple addresses are out of scope at v0.x.

## Fields

| Column | Type | Notes |
|---|---|---|
| `address_line_1` | varchar(200) | |
| `address_line_2` | varchar(200) | |
| `city` | varchar(100) | |
| `state` | varchar(100) | (or province / region) |
| `postal_code` | varchar(20) | |
| `country` | varchar(100) | ISO-3166-alpha-2 or human name; @chthonic/locale tolerates both |

## Normalisation

- `country` is **NOT** normalised on save — both `"AU"` and `"Australia"` accepted, both round-trip. `@chthonic/locale.CountryDefaults.<X>ForCountry(country)` accepts either.
- `mobile` IS normalised to E.164 on save (`"+61400123456"` regardless of input form).
- `postal_code` preserved as entered (some countries' codes are non-numeric, e.g. UK `SW1A 1AA`).

## Downstream consumers

The customer's address is read by:

- `@chthonic/billing` — invoice/estimate billing address.
- `@chthonic/booking` — service location filter.
- `@chthonic/documents` — Liquid templates (`{{ customer.address_line_1 }}` etc.).
- `@chthonic/listings` — public listing's "service area" geography.

All consumers read the customer record directly; parties does not own a normalised geography service.

## Future: multiple addresses

If a future RFC adds multiple-addresses-per-customer, the schema would shift to:

```
customer_address (
    customer_address_id PK,
    customer_id FK,
    type enum 'billing'|'shipping'|'service',
    address_line_1, address_line_2, city, state, postal_code, country,
    is_default bool,
    ...
)
```

This is **not** in v0.x. Bump major version when added.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`customers.md`](customers.md).
- [`libraries/locale/country-defaults.md`](../locale/country-defaults.md) — country normalisation.
