---
library: notifications
version: 0.1.0
related-rfcs: [0009]
related-libs: [templating, locale]
last-verified: 2026-05-22
tags: [notifications, liquid, templates]
summary: Email/SMS template rendering — Liquid + locale filters preloaded.
---

# Liquid templates

Templates live as embedded resources at `Templates/<key>.liquid`. Renderer constructs context from the publish request's `Data` + tenant config.

## Example template

`Templates/invoice.sent.liquid`:

```liquid
Hi {{ recipient.first_name }},

Your invoice {{ invoice.invoice_number }} is ready.

Amount: {{ invoice.total_amount | format_currency }}
Due: {{ invoice.due_date | format_date }}

Pay now: {{ invoice.payment_url }}
```

`format_currency` and `format_date` are preloaded via `@chthonic/locale`'s filter registration.

## Context shape

```
{
  system: { name, date_format, number_format, currency, timezone, ... },
  recipient: { first_name, last_name, email, mobile, ... },
  entity: ...,           # alias for the typed entity (invoice/booking/etc.)
  invoice: ...,           # type-specific alias if Data carries one
  booking: ...,
  ...
}
```

## Channel-specific rendering

Email uses HTML templates (`.html.liquid` suffix). SMS uses plain text. Push uses JSON title + body. In-app uses HTML body.

The renderer picks the correct template by:

```
Templates/{key}.{channel}.liquid    # channel-specific
Templates/{key}.liquid              # fallback
```

E.g. `Templates/invoice.sent.email.liquid` overrides `invoice.sent.liquid` for email channel.

## Related

- [`libraries/templating/`](../templating/), [`libraries/locale/liquid-filters.md`](../locale/liquid-filters.md).
- [`extension-points.md`](extension-points.md).
