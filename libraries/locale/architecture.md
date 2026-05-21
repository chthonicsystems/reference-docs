---
library: locale
version: 0.1.0
related-rfcs: [0003]
last-verified: 2026-05-22
tags: [locale, architecture]
summary: Internal structure of @chthonic/locale — file layout, key types, parity rules between .NET and TS.
---

# Architecture

`@chthonic/locale` is a **pure-function library**: no DI, no state, no async, no schema. The .NET package is a handful of static helpers; the npm package is the same helpers as ES modules + a React hook + a context provider.

The defining design constraint is **server-frontend parity** — a date/number/currency rendered server-side (PDF, email, data export) MUST match what the same tenant sees in the browser for the same input. The two implementations are designed in lock-step and the test suites enforce parity.

## File layout

### .NET — `chthonicsystems/locale/src/Chthonic.Locale/`

```
Chthonic.Locale.csproj
LocaleModuleMarker.cs              # Marker class for assembly scan
ServiceCollectionExtensions.cs     # AddChthonicLocale() (no-op today; forward-compat)
FormatHelper.cs                    # Static formatting functions
LiquidFormatFilters.cs             # Four Fluid filter delegates
LiquidFilterRegistration.cs        # RegisterFormatFilters(TemplateOptions)
CountryDefaults.cs                 # Country → defaults tables
TerminologyHelper.cs               # Country-default + per-tenant override merge
TimezoneValidator.cs               # IANA validation
```

### .NET tests — `chthonicsystems/locale/src/Chthonic.Locale.Tests/`

```
Chthonic.Locale.Tests.csproj
FormatHelperTests.cs               # All four formatters + edge cases (null, invalid, DST)
LiquidFormatFiltersTests.cs        # Liquid filter parity with FormatHelper
TerminologyHelperTests.cs          # Default + AU/NZ + Middle East/South Asia + override merge
TimezoneValidatorTests.cs          # Allowlist + runtime probe + invariant tests
CountryDefaultsTests.cs            # Country mapping coverage + fallback to defaults
ServiceCollectionExtensionsTests.cs # AddChthonicLocale() smoke test
```

### npm — `chthonicsystems/locale/npm/src/`

```
package.json                       # name = @chthonicsystems/locale
tsconfig.json
vitest.config.ts
index.ts                           # Public re-exports
formatters.ts                      # Pure formatters (React-free)
LocaleContext.tsx                  # LocaleProvider + LocaleContext
useFormatting.ts                   # The React hook
formatters.test.ts                 # Vitest — every formatter, every input shape
useFormatting.test.tsx             # Vitest + React Testing Library — hook + provider
```

## Key types

### `FormatHelper` (.NET)

All static, all pure (logger arg optional and only emits at `LogWarning` / `LogDebug`).

```csharp
public static class FormatHelper
{
    public const string DefaultDateFormat = "DMY";
    public const string DefaultNumberFormat = "CommaDot";
    public const string DefaultCurrency = "USD";
    public const string DefaultTimezone = "UTC";

    public static TimeZoneInfo ResolveTimeZone(string? timezone, ILogger? logger = null);
    public static string FormatDate(DateTime? value, string? dateFormat = null, string? timezone = null);
    public static string FormatDateTime(DateTime? value, string? dateFormat = null, string? timezone = null);
    public static string FormatTime(DateTime? value, string? timezone = null);
    public static string FormatZoneAbbreviation(string? timezone, DateTime? reference = null);
    public static string FormatNumber(decimal? value, string? numberFormat = null, int? decimals = null);
    public static string FormatNumber(double? value, string? numberFormat = null, int? decimals = null);
    public static string FormatCurrency(decimal? value, string? currency = null, string? numberFormat = null);
    public static string FormatCurrency(double? value, string? currency = null, string? numberFormat = null);
}
```

Output rules:

- `null` value → empty string (never "Invalid Date").
- `null` / empty timezone → UTC.
- Negative currency → minus prefix ("-$12.34"), not parentheses (Australian convention).
- `DateFormat`: `DMY` (default) / `MDY` / `YMD`.
- `NumberFormat`: `CommaDot` (default, `1,234.56`) / `DotComma` (`1.234,56`) / `SpaceDot` (`1 234.56`).

### `formatters.ts` (npm)

Same shapes, expressed for browser via `Intl`:

```ts
export const DEFAULT_DATE_FORMAT: DateFormatCode = 'DMY';
export const DEFAULT_NUMBER_FORMAT: NumberFormatCode = 'CommaDot';
export const DEFAULT_CURRENCY = 'USD';
export const DEFAULT_TIMEZONE = 'UTC';

export function formatDate(input, dateFormat?, timezone?, style?): string;
export function formatDateTime(input, dateFormat?, timezone?, style?): string;
export function formatTime(input, timezone?): string;
export function formatRelativeDate(input, timezone?, now?): string;
export function formatZoneAbbreviation(timezone, reference?): string;
export function formatNumber(n, numberFormat?, opts?): string;
export function formatCurrency(n, currency?, numberFormat?): string;

export function dateFormatToIntlPattern(fmt, style?): Intl.DateTimeFormatOptions;
export function numberFormatToIntlLocale(fmt): string;
```

The `formatRelativeDate` helper is **frontend-only** — there is no `.NET` equivalent because relative-date rendering is always a UI concern, never appears in PDFs or emails.

### `useFormatting()` hook

```ts
function useFormatting() {
  const { dateFormat, numberFormat, currency, timezone } = useLocaleContext();
  return useMemo(() => ({
    formatDate, formatDateTime, formatTime,
    formatRelativeDate, formatZoneAbbreviation,
    formatNumber, formatCurrency,
    sys: { dateFormat, numberFormat, currency, timezone },
  }), [dateFormat, numberFormat, currency, timezone]);
}
```

Memoised on the four primitives — re-renders only when the tenant's locale config changes.

### `<LocaleProvider>`

Provides context to descendant components. Without a provider, `useFormatting()` falls back to `defaultLocaleOptions` (`DMY` / `CommaDot` / `USD` / `UTC`). This keeps anonymous public surfaces working without an authenticated tenant.

## Schema

None. This library has no entities, no migrations, no tables.

`Chthonic.Locale` does NOT register an `IEntityTypeConfiguration` and does NOT contribute to any consumer's `OnModelCreating`. The `LocaleModuleMarker` exists only for symmetric assembly-scan registration with other libraries that DO contribute schema (so consumers can paste a uniform list of `ApplyConfigurationsFromAssembly` calls).

## Tests

### .NET — xUnit

Run inside the library repo: `dotnet test`.

| File | Coverage |
|---|---|
| `FormatHelperTests` | DMY/MDY/YMD short numeric; date+time round-trip; FormatTime hour cycle; UTC/AEST/AEDT zones; FormatNumber CommaDot/DotComma/SpaceDot grouping; FormatCurrency USD/AUD/EUR/GBP/JPY/AED/ZAR symbols; negative-prefix; null/empty value |
| `LiquidFormatFiltersTests` | Each filter against synthetic `TemplateContext` with `system` variable + system-default fallback + filter-arg override + null/empty input |
| `TerminologyHelperTests` | Default / AU-NZ / Middle East South Asia / unknown-country fallback / per-tenant override merge / 10 keys invariant |
| `TimezoneValidatorTests` | Known list / runtime probe / invariant: every tz emitted by `CountryDefaults.TimezoneForCountry` is in `KnownTimezones` |
| `CountryDefaultsTests` | DMY/MDY/YMD partition / CommaDot/DotComma/SpaceDot partition / GST/VAT/Sales-Tax partition / unknown-country fallback |
| `ServiceCollectionExtensionsTests` | `AddChthonicLocale()` returns the same `IServiceCollection` (smoke) |

### npm — Vitest + React Testing Library

Run inside `npm/`: `npm test`.

| File | Coverage |
|---|---|
| `formatters.test.ts` | Mirrors `FormatHelperTests` — same date/number/currency invariants verified through `Intl` |
| `useFormatting.test.tsx` | Hook output keyed off provider config; provider switching mid-tree; default fallback when no provider |

### Server-frontend parity

Parity is verified manually during library releases by running the same input through both stacks (`dotnet test FormatHelperTests --filter Parity` and `npm test formatters.parity` — patterns may exist or be added as the library matures).

## Related

- [`index.md`](index.md) — public surface.
- [`consumption.md`](consumption.md) — code-level integration.
- [`extension-points.md`](extension-points.md) — hooks consumers use.
- [RFC 0003 — Localization Package](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0003-localization-package.md) — design rationale.
