---
library: locale
version: 0.1.0
related-rfcs: [0003]
last-verified: 2026-05-22
tags: [locale, extension-points]
summary: Every hook a consumer can use to integrate or extend @chthonic/locale.
---

# Extension points

`@chthonic/locale` is a pure-function library. There are no plug-in interfaces; "extension" means "use the documented hook" or "submit an upstream PR".

## Hooks consumers use

| Hook | Layer | When |
|---|---|---|
| `services.AddChthonicLocale()` | .NET DI | Once at app startup. No-op today; future-proof. |
| `LiquidFilterRegistration.RegisterFormatFilters(TemplateOptions)` | Liquid | Once per Fluid pipeline (notifications / documents / listings / ai). |
| `<LocaleProvider options={...}>` | React | Once at app root, with the active tenant's `{ dateFormat, numberFormat, currency, timezone }`. |
| `useFormatting()` | React | In any component that renders a date / number / currency. |
| Pure formatter exports | TS | In non-component utility code. |

## Adding country defaults

A new country gets entries in:

1. `CountryDefaults.MdyCountries` / `YmdCountries` (date format).
2. `CountryDefaults.DotCommaCountries` / `SpaceDotCountries` (number format).
3. `CountryDefaults.CountryToCurrency` (currency).
4. `CountryDefaults.GstCountries` / `VatCountries` (tax name).
5. `CountryDefaults.DefaultRates` (default tax rate).
6. `CountryDefaults.CountryToTimezone` (primary IANA zone).

Then add the IANA zone to `TimezoneValidator.KnownTimezones` if it's not already there. The test suite invariant fails if `CountryDefaults.TimezoneForCountry` returns a zone not in `KnownTimezones`.

## Adding a terminology variant

A new region (e.g. South-East Asia) gets:

1. A `Dictionary<string, string>` in `TerminologyHelper` with the 10 canonical keys.
2. A `HashSet<string>` of country names that map to it.
3. A new branch in `GetTerminology(country)` that picks it.

Don't add new keys without an RFC amendment — the 10 canonical keys (`Estimate(s)`, `Invoice(s)`, `Job(s)`, `Booking(s)`, `Mechanic(s)`) are part of the public contract and consumers depend on them.

## Adding a currency symbol

Add a `case` to `FormatHelper.GetCurrencySymbol`. Keep the table short — most non-Latin currencies fall through to ISO-code-prefix display ("AED 1,234.56"), which is acceptable.

## Adding a timezone

1. Add the IANA ID to `TimezoneValidator.KnownTimezones`.
2. If the zone has a well-known abbreviation that the platform uses on customer-facing surfaces, add a case in `FormatHelper.FormatZoneAbbreviation`'s switch. Otherwise it falls through to UTC offset display ("UTC+11").

## Plug-in interface (deferred)

A future per-tenant `IFormatHelper` resolver service is anticipated. The interface would let products override formatting beyond the four primitives (e.g. PetCare's species-specific date format if one ever ships). For now, no such service exists; consumers either use the primitives as-is or [fork the library](../../platform/forking-a-library.md).

## Related

- [`index.md`](index.md) — public surface.
- [`architecture.md`](architecture.md) — internal structure.
- [`consumption.md`](consumption.md) — how to integrate.
- [`country-defaults.md`](country-defaults.md) — current tables.
- [`terminology.md`](terminology.md) — terminology variants.
- [`timezone-validation.md`](timezone-validation.md) — IANA validation.
- [`platform/forking-a-library.md`](../../platform/forking-a-library.md) — when to fork instead.
