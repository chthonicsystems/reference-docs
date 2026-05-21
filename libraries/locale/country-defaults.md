---
library: locale
version: 0.1.0
related-rfcs: [0003]
last-verified: 2026-05-22
tags: [locale, country-defaults, signup]
summary: Country → date/number/currency/tax/timezone derivation tables.
---

# Country defaults

When an admin picks a country (signup or Config Hub), `CountryDefaults` returns sensible initial values for the four locale primitives plus tax. The admin can override any value afterwards; the country pick is just a smart default.

## API

```csharp
public static class CountryDefaults
{
    public static string  DateFormatForCountry(string? country);     // "DMY" | "MDY" | "YMD"
    public static string  NumberFormatForCountry(string? country);   // "CommaDot" | "DotComma" | "SpaceDot"
    public static string  CurrencyForCountry(string? country);       // ISO-4217
    public static string  TaxNameForCountry(string? country);        // "GST" | "VAT" | "Sales Tax"
    public static decimal DefaultTaxRateForCountry(string? country); // percentage
    public static string  TimezoneForCountry(string? country);       // IANA zone
}
```

All accept either ISO-3166-alpha-2 codes (`"AU"`, `"US"`) or human-readable country names (`"Australia"`, `"United States"`). Both forms are case-insensitive. Unknown / null input falls through to worldwide defaults: `DMY` / `CommaDot` / `USD` / `Sales Tax` / `0%` / `UTC`.

## DateFormat partition

| Format | Countries (examples) |
|---|---|
| `DMY` (default) | AU, NZ, GB, IE, EU continent, India, LATAM |
| `MDY` | US, USA, Philippines |
| `YMD` | JP, CN, KR, TW |

## NumberFormat partition

| Format | Countries (examples) |
|---|---|
| `CommaDot` (default; `1,234.56`) | US, GB, AU, CA, NZ, IE, IN, SG, MY, JP |
| `DotComma` (`1.234,56`) | DE, IT, ES, NL, BE, AT, PT, GR, BR, AR, DK |
| `SpaceDot` (`1 234.56`) | FR, RU, UA, CZ, PL, NO, SE, FI |

## Currency mapping (ISO-4217)

Australia=`AUD`, NZ=`NZD`, US=`USD`, GB/UK=`GBP`, Canada=`CAD`, EU countries=`EUR`, JP=`JPY`, CN=`CNY`, IN=`INR`, PK=`PKR`, PH=`PHP`, AE=`AED`, SA=`SAR`, ZA=`ZAR`, SG=`SGD`, MY=`MYR`, TH=`THB`, ID=`IDR`, BR=`BRL`, MX=`MXN`, AR=`ARS`. Unknown → `USD`.

## TaxName + DefaultRate partition

| Tax name | Countries | Default rate |
|---|---|---|
| `GST` | AU 10%, NZ 15%, IN 18%, SG 9%, MY 6% | varies |
| `VAT` | GB 20%, IE 23%, DE 19%, FR 20%, IT 22%, ES 21%, NL 21%, BE 21%, AT 20%, PT 23%, GR 24%, SE 25%, FI 24%, DK 25%, NO 25%, PL 23%, CZ 21%, AE 5%, SA 15%, ZA 15%, JP 10% | varies |
| `Sales Tax` (default) | US, everyone else | 0 (admin configures per locality) |

## Timezone mapping (IANA)

The primary IANA zone per country. Multi-zone countries get the most populous / canonical one — admins override via the Localization section.

```
AU         → Australia/Sydney
NZ         → Pacific/Auckland
US         → America/New_York         (admin overrides for Central/Mountain/Pacific)
CA         → America/Toronto
GB / UK    → Europe/London
IE         → Europe/Dublin
DE         → Europe/Berlin
FR         → Europe/Paris
IT         → Europe/Rome
ES         → Europe/Madrid
NL         → Europe/Amsterdam
JP         → Asia/Tokyo
CN         → Asia/Shanghai
IN         → Asia/Kolkata
SG         → Asia/Singapore
MY         → Asia/Kuala_Lumpur
AE         → Asia/Dubai
SA         → Asia/Riyadh
ZA         → Africa/Johannesburg
BR         → America/Sao_Paulo
MX         → America/Mexico_City
AR         → America/Argentina/Buenos_Aires
unknown    → UTC
```

Full table in `src/Chthonic.Locale/CountryDefaults.cs` `CountryToTimezone` dictionary.

## Adding a country

1. Add entries to all six dictionaries / sets in `CountryDefaults.cs` (date format set, number format set, currency dict, tax name set, tax rate dict, timezone dict).
2. Verify the timezone IANA ID is in `TimezoneValidator.KnownTimezones` (or add it).
3. Add xUnit tests in `CountryDefaultsTests.cs`.
4. The test invariant `for each c in countries → CountryDefaults.TimezoneForCountry(c) ∈ TimezoneValidator.KnownTimezones` must hold.

## Anonymous endpoint

```
GET /api/system-defaults/by-country/{country}
```

Returns `{dateFormat, numberFormat, currency, taxName, defaultTaxRate, timezone}` for a country. Rate-limited at 10 req/min/ip. The Config Hub uses this for live preview when an admin changes their country selection.

## Related

- [`index.md`](index.md) — public surface.
- [`architecture.md`](architecture.md) — internals.
- [`consumption.md`](consumption.md) — signup flow integration.
- [`timezone-validation.md`](timezone-validation.md) — companion IANA validator.
- Source: `chthonicsystems/locale/src/Chthonic.Locale/CountryDefaults.cs`.
