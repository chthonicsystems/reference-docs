---
library: locale
version: 0.1.0
related-rfcs: [0003]
related-libs: [templating]
last-verified: 2026-05-22
tags: [locale, liquid, filters]
summary: The four Liquid format filters — format_date, format_datetime, format_number, format_currency.
---

# Liquid format filters

Four filters mirror the frontend `useFormatting()` hook so PDFs, emails, and public listings render dates / numbers / currency in the tenant's configured format.

## Filter signatures

```liquid
{{ value | format_date[: dateFormat[, timezone]] }}
{{ value | format_datetime[: dateFormat[, timezone]] }}
{{ value | format_number[: decimals[, numberFormat]] }}
{{ value | format_currency[: currency[, numberFormat]] }}
```

Defaults are read from the Liquid context's `system` variable (looking for `date_format`, `number_format`, `currency`, `timezone`). Filter args override per-call.

## Examples

```liquid
{# Defaults: read from context's system variable. #}
Due: {{ invoice.due_date | format_date }}                 → 22/05/2026
Created: {{ invoice.created_at | format_datetime }}       → 22/05/2026 3:45 pm
Total: {{ invoice.total | format_currency }}              → $1,234.56
Hours: {{ labour.hours | format_number: 1 }}              → 8.5

{# Per-call override. #}
{{ d | format_date: "MDY", "America/New_York" }}          → 05/22/2026
{{ amount | format_currency: "EUR", "DotComma" }}         → €1.234,56
```

## Input coercion

| Filter | Accepted inputs |
|---|---|
| `format_date`, `format_datetime` | `DateTime`, `DateTimeOffset`, ISO-8601 string, Unix seconds (long/int) |
| `format_number`, `format_currency` | `decimal`, `double`, `float`, `int`, `long`, numeric string |

Null / empty / unparseable input → empty string output. Never "Invalid Date" or `NaN`.

## Registration

```csharp
using Chthonic.Locale;
using Fluid;

var fluidOptions = new TemplateOptions();
LiquidFilterRegistration.RegisterFormatFilters(fluidOptions);
```

Idempotent. Call once per `TemplateOptions` instance. The four filters are then available on every template that uses that `TemplateOptions`.

## System variable shape

The Liquid context must carry a `system` variable with these snake_case property names:

```json
{
  "date_format": "DMY",
  "number_format": "CommaDot",
  "currency": "AUD",
  "timezone": "Australia/Sydney"
}
```

Templating consumers (notifications, documents, listings) populate this via their own context builders. See [`libraries/templating/`](../templating/) for the canonical Liquid pipeline.

## Negative numbers

`format_currency` always uses minus prefix, never accounting parens.

```liquid
{{ -12.34 | format_currency: "AUD" }}   → -$12.34
```

## Timezone abbreviation

There is **no** `format_zone_abbreviation` filter today. If a customer-facing template needs the zone string, the consumer's context builder pre-computes it via `FormatHelper.FormatZoneAbbreviation(...)` and passes it in as a separate context variable.

## Test parity

`Chthonic.Locale.Tests.LiquidFormatFiltersTests` runs the same input through both `FormatHelper.FormatDate` and the `format_date` filter and asserts byte-equal output. Same for the other three filters.

## Related

- [`index.md`](index.md) — public surface.
- [`architecture.md`](architecture.md) — `LiquidFormatFilters.cs` internals.
- [`libraries/templating/`](../templating/) — Liquid engine.
- [`libraries/notifications/liquid-templates.md`](../notifications/liquid-templates.md) — consumer pipeline.
- [`libraries/documents/liquid-pipeline.md`](../documents/liquid-pipeline.md) — consumer pipeline.
- [`libraries/listings/`](../listings/) — consumer pipeline.
