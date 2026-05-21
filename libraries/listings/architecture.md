---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, architecture]
summary: Listings internals — registry, slug generation, AI artifacts, public + admin endpoints.
---

# Architecture

```
src/Chthonic.Listings/
├── Domain/SystemListing.cs, SystemListingMedia.cs, AiArtifact.cs
├── Configuration/, Migrations/
├── Services/
│   ├── IListingService.cs / ListingService.cs
│   ├── ListingTemplateRegistry.cs
│   ├── SlugGenerator.cs
│   └── ListingHtmlSecurityPolicy.cs
├── AI/
│   └── AiTemplateToolExecutor.cs (extends @chthonic/ai)
├── Endpoints/
│   ├── ListingEndpoints.cs (admin)
│   └── PublicListingEndpoints.cs (anonymous)
├── Templates/
│   ├── classic/index.liquid, styles.css
│   ├── modern/...
│   ├── bold/...
│   └── elegant/...
└── ServiceCollectionExtensions.cs
```

## Caching

Public listing endpoint sets `Cache-Control: max-age=60` for anonymous users; `no-cache` for authenticated. Template content + assets cached `max-age=3600` / `max-age=86400`. Nginx rate-limits the public endpoint at 30 req/min/ip prod (600 beta).

## Anonymous URL

```
/listing/{slug}
```

Browser fetches HTML page → loads `<IsolatedPreview>` iframe pointing at `/api/listing/{slug}/render?theme=...`. Theme HTML rendered server-side via Liquid.

## Tests

`SlugGeneratorTests` (uniqueness, reserved words), `ListingTemplateRegistryTests` (feature-flag filtering), `PublicListingEndpointsTests` (caching headers, rate-limit responses).

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`slug-rules.md`](slug-rules.md), [`four-themes.md`](four-themes.md).
