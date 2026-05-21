---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, extension-points]
summary: Extension points — per-product theme, per-tier feature flags, slug rules.
---

# Extension points

| Hook | Use |
|---|---|
| Per-product 5th theme | Drop `Templates/<theme-name>/index.liquid` |
| `ListingTemplateAI/Bold/Elegant` flags | Per-tier theme availability |
| Slug rules | Customise reserved words |
| AI generation | `AiTemplateToolExecutor` (sister to docs AI) |

## Adding a 5th theme

```
Templates/marketplace/
├── index.liquid
├── styles.css
└── settings.json
```

Register: `ListingTemplateRegistry.RegisterTheme("marketplace")`. Default-enable per tier via `tier_feature` row.

## Custom reserved words

```csharp
builder.Services.AddChthonicListings(opts =>
{
    opts.AdditionalReservedSlugs = new[] { "about", "contact", "help" };
});
```

## Related

- [`four-themes.md`](four-themes.md), [`slug-rules.md`](slug-rules.md), [`ai-generation.md`](ai-generation.md).
