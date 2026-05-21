---
library: locale
version: 0.1.0
related-rfcs: [0003]
last-verified: 2026-05-22
tags: [locale, terminology, overrides]
summary: Country-default + per-tenant override merge for the 10 canonical terminology keys.
---

# Terminology

`TerminologyHelper` resolves the 10 canonical terminology keys with country-derived defaults that admins can override per-tenant.

## 10 canonical keys

```
Estimate    Estimates
Invoice     Invoices
Job         Jobs
Booking     Bookings
Mechanic    Mechanics
```

Singular + plural pairs. The set is fixed; **adding a key requires an RFC amendment** because consumers depend on the keys being stable.

## Country variants

| Variant | Trigger | Key changes (vs default) |
|---|---|---|
| Default | unknown country | `Estimate(s)`, `Invoice(s)`, `Job(s)`, `Booking(s)`, `Mechanic(s)` |
| AU/NZ | `"Australia"`, `"New Zealand"` | `Estimate(s)` → `Quote(s)`, `Invoice(s)` → `Tax Invoice(s)` |
| Middle East / South Asia | UAE, SA, IN, PK, QA, BH, KW, OM, JO, IQ, BD, LK, NP | `Estimate(s)` → `Quotation(s)`, `Invoice(s)` → `Tax Invoice(s)`, `Job(s)` → `Job Card(s)`, `Booking(s)` → `Appointment(s)`, `Mechanic(s)` → `Technician(s)` |

## API

```csharp
// Country-defaults only.
Dictionary<string, string> defaults = TerminologyHelper.GetTerminology(country);

// Country defaults + per-tenant overrides merged.
Dictionary<string, string> effective = TerminologyHelper.GetTerminology(country, overrides);

// The canonical key list (used to validate incoming PUT payloads).
IReadOnlyList<string> keys = TerminologyHelper.Keys;
```

## Override merge rules

```csharp
var defaults = GetTerminology(country);                       // 10 keys
var overrides = new Dictionary<string, string?> {              // 0–10 entries
    ["Mechanic"] = "Engineer",
    ["Mechanics"] = "Engineers",
    ["Estimate"] = "",                                         // empty = clear override
};
var result = GetTerminology(country, overrides);
//   "Mechanic" → "Engineer"
//   "Mechanics" → "Engineers"
//   "Estimate" → country default (empty override is dropped)
//   ... other 7 keys: country default
```

Empty / whitespace override values are **dropped** (not written) — consumers send empty string to clear an override.

## Endpoint shape

`/api/systems/my-system/terminology`:

- `GET` returns the merged `Dictionary<string, string>` for the active tenant.
- `PUT` accepts `Dictionary<string, string?>` of overrides; non-canonical keys are rejected with 400. Empty string clears an override.

The `terminology_override` table has one row per `(system_id, key)`. Empty overrides are deleted, not stored.

## Test coverage

`Chthonic.Locale.Tests.TerminologyHelperTests`:

- Default returns canonical 10.
- AU/NZ branch returns Quote / Tax Invoice variants.
- Middle East / South Asia branch returns Quotation / Tax Invoice / Job Card / Appointment / Technician variants.
- Unknown country falls through to default.
- `Keys` list contains exactly the 10 expected keys.
- Override merge: non-empty override wins; empty override is dropped; non-canonical key is ignored by the merge (the endpoint's validator rejects it before reaching this method).

## Related

- [`index.md`](index.md) — public surface.
- [`architecture.md`](architecture.md) — internals.
- [`country-defaults.md`](country-defaults.md) — how country drives the variant pick.
- [`libraries/tenant/config-hub.md`](../tenant/config-hub.md) — Terminology section consumer.
- Source: `chthonicsystems/locale/src/Chthonic.Locale/TerminologyHelper.cs`.
