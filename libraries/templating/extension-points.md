---
library: templating
version: 0.1.0
related-rfcs: [0020]
last-verified: 2026-05-22
tags: [templating, extension-points]
summary: Extension points — TemplateOptionsFactory, custom filters/tags, security policy override.
---

# Extension points

| Hook | Use |
|---|---|
| `TemplateOptionsFactory.Create()` | Get fresh `TemplateOptions` with locale filters; add consumer filters/tags |
| `RenderedHtmlSecurityPolicy` | Override allowed tags/attrs/URL schemes |
| `<IsolatedTemplatePreview sandbox="…">` | Tighten iframe sandbox per consumer |

## Adding a custom filter

```csharp
options.Filters.AddFilter("relative_url", (input, args, ctx) =>
{
    var path = input.ToStringValue();
    return new ValueTask<FluidValue>(StringValue.Create($"/{path}"));
});
```

## Adding a custom tag

```csharp
options.Tags.Add<MyCustomTag>("my_tag", new MyCustomTagParser());
```

## Tighter security policy

```csharp
public class StricterPolicy : RenderedHtmlSecurityPolicy
{
    protected override HashSet<string> AllowedTags { get; } = new() { "div", "span", "p" };
    protected override HashSet<string> AllowedAttributes { get; } = new() { "class" };
}

builder.Services.AddSingleton<RenderedHtmlSecurityPolicy, StricterPolicy>();
```

`ListingHtmlSecurityPolicy` ships as an example stricter variant for public listings.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`liquid-engine.md`](liquid-engine.md), [`iframe-isolation.md`](iframe-isolation.md), [`ai-output-sanitization.md`](ai-output-sanitization.md).
