---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, themes]
summary: Four pre-built listing themes — Classic, Modern, Bold, Elegant.
---

# Four themes

Same shape as `@chthonic/documents` themes. Per-tier availability via feature flags.

## Theme set

| Theme | Style | Feature flag |
|---|---|---|
| Classic | Default; traditional | always available |
| Modern | Clean minimalist | `ListingTemplateModern` (Standard+Premium) |
| Bold | High-contrast | `ListingTemplateBold` (Premium) |
| Elegant | Serif + light colour | `ListingTemplateElegant` (Premium) |

## Tenant pick

```
PUT /api/systems/my-system/listing
{ "templateName": "modern" }
```

Server enforces: tenant's tier must have the matching feature flag enabled.

## Custom AI theme

5th option: AI-generated theme. Stored as `ai_artifact` row + S3-hosted Liquid + CSS. Live version determined by `system_listing.active_ai_artifact_id`.

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`ai-generation.md`](ai-generation.md), [`extension-points.md`](extension-points.md).
