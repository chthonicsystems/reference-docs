---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, themes]
summary: Four pre-built themes — Classic, Modern, Bold, Elegant — per document type.
---

# Four pre-built themes

Each of the 4 doc types ships 4 themes. 16 templates total at v0.1.0.

| Theme | Style |
|---|---|
| Classic | Traditional formal layout (most common; default) |
| Modern | Clean minimalist (typography-led) |
| Bold | High-contrast, strong colours |
| Elegant | Serif typography + light colour |

## Per-tenant theme pick

```sql
-- system_configuration extension columns owned by consumer
ALTER TABLE system_configuration ADD COLUMN invoice_template_theme VARCHAR(50) NOT NULL DEFAULT 'classic';
ALTER TABLE system_configuration ADD COLUMN estimate_template_theme VARCHAR(50) NOT NULL DEFAULT 'classic';
-- etc per doc type
```

## Theme structure

```
Templates/invoice-classic/
├── index.liquid
├── styles.css
└── settings.json    # default labels, colors

Templates/invoice-modern/
├── index.liquid
├── styles.css
└── settings.json
```

Theme switch = template directory swap. Labels customisable via `settings.json` overrides per tenant.

## Customisation surface

Admins customise per theme:

- Labels (e.g. "Invoice" → "Tax Invoice").
- Theme colours (3 brand-token CSS variables).
- Section visibility (toggle hide/show).
- View-picker (which view's fields to render).

## Related

- [`liquid-pipeline.md`](liquid-pipeline.md), [`document-designer-shell.md`](document-designer-shell.md), [`extension-points.md`](extension-points.md).
