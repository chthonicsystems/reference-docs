---
library: locale
package-nuget: Chthonic.Locale
package-npm: '@chthonicsystems/locale'
version: 0.1.0
related-rfcs: [0003]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [foundational, formatting, localization, liquid]
summary: Date/number/currency formatting + Liquid filters + country defaults + terminology + timezone validation.
---

# `@chthonicsystems/locale` / `Chthonic.Locale`

Localization primitives shared by every product on the Chthonic platform. Pure functions; zero runtime state. Both .NET and TypeScript packages render identically — same dates, same numbers, same currency strings — so a value rendered server-side in a PDF matches what the browser renders for the same tenant.

## Purpose

Every user-visible date, number, and currency rendered anywhere in a Chthonic product MUST come through this library. Tenants configure four primitives — `DateFormat` (DMY / MDY / YMD), `NumberFormat` (CommaDot / DotComma / SpaceDot), `Currency` (ISO-4217), `Timezone` (IANA) — and every render respects them.

Server-side: `Chthonic.Locale.FormatHelper.{FormatDate,FormatDateTime,FormatTime,FormatNumber,FormatCurrency,FormatZoneAbbreviation}`.

Frontend: `useFormatting()` React hook + pure helpers exported from `@chthonicsystems/locale`.

Liquid templates (PDFs, emails, public listings): `format_date`, `format_datetime`, `format_number`, `format_currency` filters.

Plus three companion concerns: country-derived defaults (when an admin picks a country, what's the right initial config?), tenant terminology overrides (Estimate → Quote → Quotation), IANA timezone validation.

## Public surface

### .NET

**Package:** `Chthonic.Locale` (NuGet)

| Type | File | Role |
|---|---|---|
| `FormatHelper` | `src/Chthonic.Locale/FormatHelper.cs` | Static formatting functions: `FormatDate`, `FormatDateTime`, `FormatTime`, `FormatNumber`, `FormatCurrency`, `FormatZoneAbbreviation`, `ResolveTimeZone` |
| `LiquidFormatFilters` | `src/Chthonic.Locale/LiquidFormatFilters.cs` | The four Fluid filters mirroring the frontend hook |
| `LiquidFilterRegistration` | `src/Chthonic.Locale/LiquidFilterRegistration.cs` | `RegisterFormatFilters(TemplateOptions)` — call once per Fluid pipeline |
| `CountryDefaults` | `src/Chthonic.Locale/CountryDefaults.cs` | `{DateFormat,NumberFormat,Currency,TaxName,DefaultTaxRate,Timezone}ForCountry(iso2OrName)` |
| `TerminologyHelper` | `src/Chthonic.Locale/TerminologyHelper.cs` | `GetTerminology(country, overrides?)` — country-default + per-tenant override merge |
| `TimezoneValidator` | `src/Chthonic.Locale/TimezoneValidator.cs` | `IsValid(zone)` — IANA zone validation against curated allowlist + runtime probe |
| `ServiceCollectionExtensions` | `src/Chthonic.Locale/ServiceCollectionExtensions.cs` | `services.AddChthonicLocale()` (currently no-op; in place for forward compat) |
| `LocaleModuleMarker` | `src/Chthonic.Locale/LocaleModuleMarker.cs` | Marker class for assembly scan in consumer `DbContext.OnModelCreating` (not used today; ships for symmetry with other libs) |

All `FormatHelper` and `CountryDefaults` methods are pure static — no DI, no state. `LiquidFilterRegistration` is a static helper that registers four filter delegates onto a `Fluid.TemplateOptions` instance.

### npm

**Package:** `@chthonicsystems/locale`

| Export | File | Role |
|---|---|---|
| `useFormatting()` | `npm/src/useFormatting.ts` | React hook returning `{ formatDate, formatDateTime, formatTime, formatRelativeDate, formatZoneAbbreviation, formatNumber, formatCurrency, sys }` |
| `<LocaleProvider>` | `npm/src/LocaleContext.tsx` | React context provider; wrap your app inside |
| `LocaleContext`, `useLocaleContext` | `npm/src/LocaleContext.tsx` | Direct context access for non-component code |
| `LocaleOptions`, `defaultLocaleOptions` | `npm/src/LocaleContext.tsx` | Options type + fallbacks |
| Pure helpers | `npm/src/formatters.ts` | `formatDate`, `formatDateTime`, `formatTime`, `formatRelativeDate`, `formatZoneAbbreviation`, `formatNumber`, `formatCurrency` — same shapes as the hook, no React |
| `dateFormatToIntlPattern`, `numberFormatToIntlLocale` | `npm/src/formatters.ts` | Public helpers if a consumer needs to talk directly to `Intl` |
| `DEFAULT_DATE_FORMAT`, `DEFAULT_NUMBER_FORMAT`, `DEFAULT_CURRENCY`, `DEFAULT_TIMEZONE` | `npm/src/formatters.ts` | Fallback constants (DMY / CommaDot / USD / UTC) |

Type exports: `DateFormatCode` (`'DMY' \| 'MDY' \| 'YMD'`), `NumberFormatCode` (`'CommaDot' \| 'DotComma' \| 'SpaceDot'`), `DateStyle` (`'short' \| 'medium' \| 'long'`), `FormatNumberOptions`.

## Dependencies

| Dep | Purpose |
|---|---|
| .NET 9 (BCL) | `TimeZoneInfo`, `CultureInfo`, ICU on .NET 6+ resolves IANA IDs natively |
| `Fluid` (NuGet, transitive) | `TemplateOptions`, `FilterArguments`, `FluidValue` for Liquid filter wiring |
| `Microsoft.Extensions.{DependencyInjection.Abstractions,Logging.Abstractions}` | DI extension + logger interface (logger optional in every method) |
| React 18+ (peer dep, npm) | Hook + provider |

The .NET package has no domain dependencies (no other Chthonic.*). The npm package is React-only.

## Extension points

| Hook | Use |
|---|---|
| `LiquidFilterRegistration.RegisterFormatFilters(TemplateOptions)` | Called by every Liquid consumer (notifications, documents, listings, ai). Idempotent. |
| `LocaleProvider options={...}` | Mount once at app root with the current tenant's `{ dateFormat, numberFormat, currency, timezone }`. |
| `CountryDefaults.<X>ForCountry(country)` | Used by the signup flow + Config Hub to seed defaults for new tenants. |
| `TerminologyHelper.GetTerminology(country, overrides)` | Used by the terminology endpoint to merge per-tenant overrides on top of country defaults. |

There are no plug-in interfaces — locale is a pure-function library. Adding a new country, new currency symbol, new terminology key, or new timezone is a code change in this repo.

See [`extension-points.md`](extension-points.md) for the full list of how each hook is used.

## Consuming this library

```csharp
// File: api/Program.cs
using Chthonic.Locale;
using Fluid;

builder.Services.AddChthonicLocale();

var fluidOptions = new TemplateOptions();
LiquidFilterRegistration.RegisterFormatFilters(fluidOptions);
builder.Services.AddSingleton(fluidOptions);
```

```tsx
// File: web/src/App.tsx
import { LocaleProvider, defaultLocaleOptions } from '@chthonicsystems/locale';

function App() {
  const { user } = useAuth();
  const opts = user?.system ?? defaultLocaleOptions;
  return (
    <LocaleProvider options={opts}>
      {/* rest of app */}
    </LocaleProvider>
  );
}
```

Full walkthrough including signup defaults wiring + Liquid template usage in [`consumption.md`](consumption.md).

## Related

- [`architecture.md`](architecture.md) — internal structure + key types + tests.
- [`consumption.md`](consumption.md) — full code-level integration walkthrough.
- [`extension-points.md`](extension-points.md) — every hook a consumer can use.
- [`liquid-filters.md`](liquid-filters.md) — deep-ref for the four Liquid filters.
- [`country-defaults.md`](country-defaults.md) — country → date/number/currency/tax/timezone tables.
- [`terminology.md`](terminology.md) — country-default + per-tenant override merge.
- [`timezone-validation.md`](timezone-validation.md) — IANA validation strategy.
- Library repo: [chthonicsystems/locale](https://github.com/chthonicsystems/locale).
- Governing RFC: [RFC 0003](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0003-localization-package.md).
