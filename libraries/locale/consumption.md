---
library: locale
version: 0.1.0
related-rfcs: [0003]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [locale, consumption]
summary: Full code-level integration walkthrough for @chthonic/locale.
---

# Consuming `@chthonic/locale`

End-to-end integration in a Chthonic-platform consumer. Steps mirror what TorqueTech does today; sister-products copy this pattern.

## 1. Add package references

**File:** `api/<Project>.Api.csproj`

```xml
<ItemGroup>
  <PackageReference Include="Chthonic.Locale" Version="0.1.0" />
</ItemGroup>
```

**File:** `web/package.json`

```json
{
  "dependencies": {
    "@chthonicsystems/locale": "0.1.0"
  }
}
```

NuGet + npm auth setup is in [`platform/library-consumption.md`](../../platform/library-consumption.md).

## 2. .NET — register DI + Liquid filters

**File:** `api/Program.cs`

```csharp
using Chthonic.Locale;
using Fluid;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddChthonicLocale();   // no-op today; in place for forward compat

// One TemplateOptions instance per Liquid pipeline (PDFs, emails, listings).
// Register the four format filters once; they read tenant config from the
// Liquid context's `system` variable at filter-invocation time.
var fluidOptions = new TemplateOptions();
LiquidFilterRegistration.RegisterFormatFilters(fluidOptions);
builder.Services.AddSingleton(fluidOptions);
```

If you have multiple Liquid pipelines (notifications + documents + listings, each with their own `TemplateOptions`), register the filters on each.

## 3. .NET — render a date/number/currency

**File:** `api/Features/Invoices/InvoiceCardPdfService.cs`

```csharp
using Chthonic.Locale;

public string RenderDueDate(DateTime? dueDate, string dateFormat, string timezone)
{
    return FormatHelper.FormatDate(dueDate, dateFormat, timezone);
    // dueDate=2026-05-22T00:00Z, DMY/Australia/Sydney → "22/05/2026"
}

public string RenderTotal(decimal? total, string currency, string numberFormat)
{
    return FormatHelper.FormatCurrency(total, currency, numberFormat);
    // total=12.34, AUD/CommaDot → "$12.34"
}
```

For Liquid templates that already carry a `system` variable in their context, just use the filters:

```liquid
Due: {{ invoice.due_date | format_date }}
Total: {{ invoice.total | format_currency }}
Note: {{ invoice.created_at | format_datetime }}
```

The `system` variable's `date_format`, `number_format`, `currency`, `timezone` properties feed the filters as defaults.

## 4. .NET — country-derived defaults

**File:** `api/Features/Signup/SignupService.cs`

```csharp
using Chthonic.Locale;

var defaults = new SystemDefaults
{
    DateFormat   = CountryDefaults.DateFormatForCountry(country),
    NumberFormat = CountryDefaults.NumberFormatForCountry(country),
    Currency     = CountryDefaults.CurrencyForCountry(country),
    TaxName      = CountryDefaults.TaxNameForCountry(country),
    TaxRate      = CountryDefaults.DefaultTaxRateForCountry(country),
    Timezone     = CountryDefaults.TimezoneForCountry(country),
};
```

Used by the signup flow when a new tenant picks a country, plus the anonymous endpoint exposed via `/api/system-defaults/by-country/{country}` (the Config Hub consumes this when an admin changes their country).

## 5. .NET — tenant terminology

**File:** `api/Features/Systems/Sections/TerminologySectionService.cs`

```csharp
using Chthonic.Locale;

public Dictionary<string, string> GetEffective(int systemId)
{
    var system = _db.Systems.AsNoTracking().First(s => s.SystemId == systemId);
    var overrides = LoadOverridesForSystem(systemId);  // Dictionary<string, string?>
    return TerminologyHelper.GetTerminology(system.Country, overrides);
}
```

Used by the `/api/systems/my-system/terminology` GET endpoint. Returns the 10 canonical keys with country-derived defaults overlaid by per-tenant overrides.

## 6. .NET — IANA timezone validation

**File:** `api/Features/Systems/Sections/LocalizationSectionService.cs`

```csharp
using Chthonic.Locale;

if (!TimezoneValidator.IsValid(input.Timezone))
{
    return Results.BadRequest(new ValidationErrorResponse
    {
        Message = "Validation failed",
        Errors = new() { ["timezone"] = $"Unknown IANA zone. Examples: {string.Join(", ", TimezoneValidator.ExampleValid())}" },
    });
}
```

Validator runs as the consumer's tenant config is saved.

## 7. Frontend — mount `<LocaleProvider>`

**File:** `web/src/App.tsx`

```tsx
import { LocaleProvider, defaultLocaleOptions } from '@chthonicsystems/locale';
import { useAuth } from '../contexts/AuthContext';

function App() {
  const { user } = useAuth();
  const opts = user?.system
    ? {
        dateFormat:   user.system.dateFormat,
        numberFormat: user.system.numberFormat,
        currency:     user.system.currency,
        timezone:     user.system.timezone,
      }
    : defaultLocaleOptions;
  return (
    <LocaleProvider options={opts}>
      {/* Rest of the app */}
    </LocaleProvider>
  );
}
```

Pre-auth public surfaces (login, signup, public listing) render with `defaultLocaleOptions` — DMY / CommaDot / USD / UTC. Once the user authenticates and `useAuth().user.system` becomes available, the provider switches; descendant components re-render with the tenant's config.

## 8. Frontend — render dates / numbers / currencies in components

**File:** `web/src/pages/InvoiceDetail.tsx`

```tsx
import { useFormatting } from '@chthonicsystems/locale';

export function InvoiceDetail({ invoice }) {
  const { formatDate, formatCurrency, formatRelativeDate } = useFormatting();
  return (
    <article>
      <h2>Invoice #{invoice.number}</h2>
      <p>Due: {formatDate(invoice.dueDate)}</p>
      <p>Total: {formatCurrency(invoice.total)}</p>
      <p>Created {formatRelativeDate(invoice.createdAt)}</p>
    </article>
  );
}
```

**Never**:
- Call `toLocaleDateString` / `toLocaleString` / `toFixed` directly.
- Hard-code `$` prefixes.
- Use moment / date-fns for *formatting* (parsing is fine).

Always go through `useFormatting()` so the output respects the active tenant.

## 9. Frontend — non-component code

For utility code that can't use a hook (e.g. validation messages built outside React), import the pure formatters:

```ts
import { formatCurrency, DEFAULT_CURRENCY, DEFAULT_NUMBER_FORMAT } from '@chthonicsystems/locale';

export function buildErrorMessage(maxAmount: number) {
  // No tenant context here — fall back to defaults.
  return `Maximum allowed amount: ${formatCurrency(maxAmount, DEFAULT_CURRENCY, DEFAULT_NUMBER_FORMAT)}`;
}
```

If you need tenant-aware formatting in utility code, plumb the four primitives through as parameters rather than re-creating a global state.

## 10. Verification

After integration:

- [ ] PDFs render the same date format as the browser for the same tenant.
- [ ] Email templates render the same currency string as the browser.
- [ ] Customer-facing surfaces (booking confirmations, public listings) include a visible timezone abbreviation via `formatZoneAbbreviation`.
- [ ] Validation rejects unknown IANA zones at save time (the Localization section's PUT endpoint).
- [ ] The four Liquid filters work in every Liquid pipeline (notifications, documents, listings).

## Related

- [`index.md`](index.md) — public surface.
- [`architecture.md`](architecture.md) — internal structure.
- [`extension-points.md`](extension-points.md) — every hook a consumer uses.
- [`liquid-filters.md`](liquid-filters.md) — deep-ref for the four filters.
- [`country-defaults.md`](country-defaults.md) — country mapping table.
- [`terminology.md`](terminology.md) — terminology helper.
- [`timezone-validation.md`](timezone-validation.md) — IANA validator.
- [`platform/library-consumption.md`](../../platform/library-consumption.md) — NuGet/npm auth.
