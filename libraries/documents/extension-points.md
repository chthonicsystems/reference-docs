---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, extension-points]
summary: Extension points — per-product theme, custom context builder, AI tool executor.
---

# Extension points

| Hook | Use |
|---|---|
| Per-product theme | Add a 5th theme by dropping `Templates/{type}-{theme}/index.liquid` |
| `TypeTemplateContextBuilder` override | Custom context per consumer (e.g. extra fields) |
| `Ai{Type}TemplateToolExecutor` per type | AI generation hooks |
| Gotenberg URL | Override sidecar URL |

## Adding a custom theme

```
Templates/invoice-mybrand/
├── index.liquid                # main template
├── styles.css                  # CSS
└── settings.json               # default labels + colors
```

Register in `InvoiceTemplateRegistry.RegisterTheme("mybrand")`. Per-tenant pick via `system_configuration.invoice_template_theme = 'mybrand'`.

## Per-product context

```csharp
public class TTInvoiceContextBuilder : InvoiceTemplateContextBuilder
{
    protected override async Task<InvoiceTemplateContext> BuildAsync(int invoiceId)
    {
        var ctx = await base.BuildAsync(invoiceId);
        // Add TT-specific Vehicle info
        ctx.Vehicle = await _vehicles.GetByIdAsync(...);
        return ctx;
    }
}

builder.Services.AddScoped<InvoiceTemplateContextBuilder, TTInvoiceContextBuilder>();
```

## Related

- [`four-themes.md`](four-themes.md), [`document-designer-shell.md`](document-designer-shell.md), [`ai-generation.md`](ai-generation.md).
