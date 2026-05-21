---
library: documents
version: 0.1.0
related-rfcs: [0012]
related-libs: [templating, locale]
last-verified: 2026-05-22
tags: [documents, liquid, pipeline]
summary: Liquid + locale-filter pipeline shared across all four document types.
---

# Liquid pipeline

The library reuses `@chthonic/templating` for Liquid + `@chthonic/locale` filters.

## Per-doc-type context

Each doc type has a typed context object:

```csharp
public class InvoiceTemplateContext : TypeTemplateContext
{
    public Invoice Invoice { get; set; } = null!;
    public Customer Customer { get; set; } = null!;
    public List<InvoiceItem> Items { get; set; } = [];
    public System System { get; set; } = null!;
}
```

Context-builder loads from DB; renderer passes to Liquid.

## Liquid template

```liquid
<h1>{{ invoice.invoice_number }}</h1>

<p>To: {{ customer.first_name }} {{ customer.last_name }}</p>
<p>Date: {{ invoice.created_at | format_date }}</p>
<p>Due: {{ invoice.due_date | format_date }}</p>

<table>
  {% for item in items %}
  <tr>
    <td>{{ item.description }}</td>
    <td>{{ item.quantity }}</td>
    <td>{{ item.unit_price | format_currency }}</td>
  </tr>
  {% endfor %}
</table>

<p>Total: {{ invoice.total_amount | format_currency }}</p>
```

Locale filters preloaded by the templating library.

## Per-tenant overrides

Labels (e.g. "Invoice" → "Tax Invoice" via `@chthonic/locale.terminology`) substitute via Liquid context. Themes (CSS) swap by template directory selection.

## Related

- [`gotenberg-pdf.md`](gotenberg-pdf.md), [`four-themes.md`](four-themes.md).
- [`libraries/templating/`](../templating/), [`libraries/locale/liquid-filters.md`](../locale/liquid-filters.md).
