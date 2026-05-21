---
library: templating
version: 0.1.0
related-rfcs: [0020]
last-verified: 2026-05-22
tags: [templating, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/templating`

## 1. Add package references

```xml
<PackageReference Include="Chthonic.Templating" Version="0.1.0" />
```

```json
"@chthonicsystems/templating": "0.1.0"
```

## 2. Register DI

```csharp
using Chthonic.Templating;

builder.Services.AddChthonicTemplating();
```

This registers `TemplateOptionsFactory`, `LiquidTemplateRenderer`, and `RenderedHtmlSecurityPolicy`.

## 3. Get a TemplateOptions for your pipeline

```csharp
var factory = serviceProvider.GetRequiredService<TemplateOptionsFactory>();
var options = factory.Create();

// Add pipeline-specific filters / tags:
options.Filters.AddFilter("currency_with_code", (input, args, ctx) => /* … */);

// Register the final options as a keyed service:
builder.Services.AddKeyedSingleton("notifications-template-options", options);
```

`TemplateOptions` is mutable; each pipeline (notifications / documents / listings) gets its own instance to avoid filter leakage.

## 4. Render

```csharp
public class TemplateConsumer(ITemplateRenderer renderer)
{
    public async Task<string> RenderEmailAsync(string liquidSource, EmailContext ctx)
    {
        var options = ... // your pipeline's TemplateOptions
        return await renderer.RenderAsync(liquidSource, ctx, options);
    }
}
```

## 5. Validate AI-generated output

```csharp
public class AiOutputValidator(RenderedHtmlSecurityPolicy policy)
{
    public ValidationResult Validate(string aiHtml)
    {
        return policy.Validate(aiHtml);   // returns OK / errors
    }
}
```

Reject AI output that includes disallowed tags, attributes, or script.

## 6. Frontend — iframe preview

```tsx
import { IsolatedTemplatePreview } from '@chthonicsystems/templating';

const renderedHtml = await api.post('/api/document-templates/preview', { ... });

<IsolatedTemplatePreview html={renderedHtml} sandbox="allow-same-origin" />
```

The component renders into a fresh iframe with the supplied `sandbox` attribute. CSS isolated; inline scripts blocked unless `sandbox="allow-scripts"` (rarely needed).

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`liquid-engine.md`](liquid-engine.md), [`iframe-isolation.md`](iframe-isolation.md), [`ai-output-sanitization.md`](ai-output-sanitization.md).
