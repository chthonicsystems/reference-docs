---
library: templating
package-nuget: Chthonic.Templating
package-npm: '@chthonicsystems/templating'
version: 0.1.0
related-rfcs: [0020]
related-libs: [locale]
last-verified: 2026-05-22
tags: [cross-cutting, liquid, templating]
summary: Liquid engine + validator + AI-output sanitization + iframe isolation. One canonical engine for notifications/documents/listings/ai.
---

# `@chthonicsystems/templating` / `Chthonic.Templating`

The single Liquid pipeline shared by every consumer that renders templated output: notifications, documents, listings, AI-generated previews. Wraps `Fluid` (Liquid for .NET) with platform-standard filter registration, AI-output sanitization, and `<IsolatedTemplatePreview>` for browser-side iframe isolation.

## Purpose

- One canonical Fluid `TemplateOptions` setup so every consumer renders Liquid identically.
- Standard registration of `@chthonic/locale`'s four format filters (`format_date`, `format_datetime`, `format_number`, `format_currency`).
- HTML/CSS validator (`RenderedHtmlSecurityPolicy`) for templates that accept user/AI input.
- React `<IsolatedTemplatePreview>` component renders templates in an iframe (CSS isolation + XSS containment).

## Public surface

### .NET

| Type | File | Role |
|---|---|---|
| `ITemplateRenderer` / `LiquidTemplateRenderer` | `src/Chthonic.Templating/LiquidTemplateRenderer.cs` | Render Liquid string + context → HTML |
| `RenderedHtmlSecurityPolicy` | `src/Chthonic.Templating/RenderedHtmlSecurityPolicy.cs` | Validates rendered HTML against allowed tags / attrs / URL schemes |
| `TemplateOptionsFactory` | `src/Chthonic.Templating/TemplateOptionsFactory.cs` | Standard `Fluid.TemplateOptions` construction with locale filters preloaded |
| `services.AddChthonicTemplating()` | `src/Chthonic.Templating/ServiceCollectionExtensions.cs` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<IsolatedTemplatePreview html={...}>` | Renders `html` inside a sandboxed iframe |
| `liquidPreviewClient` | (future) browser-side Liquid via WASM |

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/locale` | `LiquidFilterRegistration.RegisterFormatFilters` |
| `Fluid` | Liquid engine |

## Extension points

| Hook | Use |
|---|---|
| `TemplateOptionsFactory.Create()` | Returns a fresh `Fluid.TemplateOptions` with format filters; consumers add their own filters/tags |
| `RenderedHtmlSecurityPolicy` config | Override allowed tags / attrs / URL schemes per consumer |
| `<IsolatedTemplatePreview>` props | iframe sandbox attribute string customisable for stricter / looser policy |

## Consuming this library

```csharp
using Chthonic.Templating;

builder.Services.AddChthonicTemplating();

// Get a TemplateOptions seeded with locale filters:
var options = builder.Services.BuildServiceProvider()
    .GetRequiredService<TemplateOptionsFactory>().Create();

// Add consumer-specific filters / tags:
options.Filters.AddFilter("relative_url", MyRelativeUrlFilter);

builder.Services.AddSingleton(options);
```

```tsx
import { IsolatedTemplatePreview } from '@chthonicsystems/templating';

<IsolatedTemplatePreview html={renderedHtml} sandbox="allow-same-origin" />
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`liquid-engine.md`](liquid-engine.md), [`iframe-isolation.md`](iframe-isolation.md), [`ai-output-sanitization.md`](ai-output-sanitization.md).
- [RFC 0020](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0020-templating.md).
