---
library: templating
version: 0.1.0
related-rfcs: [0020]
last-verified: 2026-05-22
tags: [templating, architecture]
summary: Templating internals — Fluid wrapper, RenderedHtmlSecurityPolicy, TemplateOptionsFactory.
---

# Architecture

```
src/Chthonic.Templating/
├── LiquidTemplateRenderer.cs            # ITemplateRenderer impl
├── TemplateOptionsFactory.cs            # standard Fluid.TemplateOptions
├── RenderedHtmlSecurityPolicy.cs        # HTML output validator
├── ListingHtmlSecurityPolicy.cs         # listings-specific policy (extracted with PR 18)
├── TemplatingModuleMarker.cs
└── ServiceCollectionExtensions.cs

npm/src/
├── IsolatedTemplatePreview.tsx          # iframe-isolated preview
└── index.ts
```

## TemplateOptionsFactory

Returns a fresh `Fluid.TemplateOptions` instance with:

- `LiquidFilterRegistration.RegisterFormatFilters(options)` already called — `format_date`, `format_datetime`, `format_number`, `format_currency` available.
- Default member access: properties via `.Property` and `.member_with_underscore` accessor.
- ISO-date-string parsing built in.

Consumers extend the returned options with their own filters/tags, then register the final `TemplateOptions` as singleton.

## RenderedHtmlSecurityPolicy

Validates rendered HTML against an allowlist:

- Allowed tags: `div`, `span`, `p`, `h1-h6`, `a`, `img`, `ul`, `ol`, `li`, `table`, `tr`, `td`, `th`, `style`, etc.
- Allowed attributes: `class`, `id`, `style`, `href`, `src`, `alt`, `width`, `height`.
- Allowed URL schemes on `href`: `https`, `mailto`, relative.
- Allowed URL schemes on `src`: `https`, `data:image/*`.
- Style attributes: only `class` (no inline `style="…"` for AI-generated content).

`ListingHtmlSecurityPolicy` (PR 18 extraction) is a stricter variant for public listings — additionally restricts inline scripts entirely.

## Tests

| File | Coverage |
|---|---|
| `LiquidTemplateRendererTests` | Render parity + filter wiring |
| `RenderedHtmlSecurityPolicyTests` | Allowlist enforcement; XSS attempts rejected |
| `TemplateOptionsFactoryTests` | Locale filters preloaded |

## Related

- [`liquid-engine.md`](liquid-engine.md), [`iframe-isolation.md`](iframe-isolation.md), [`ai-output-sanitization.md`](ai-output-sanitization.md).
- [RFC 0020](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0020-templating.md).
