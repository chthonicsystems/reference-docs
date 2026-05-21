---
library: listings
package-nuget: Chthonic.Listings
package-npm: '@chthonicsystems/listings'
version: 0.1.0
related-rfcs: [0014]
related-libs: [tenant, templating, files, ai]
last-verified: 2026-05-22
tags: [feature, marketplace, public-listing, four-themes]
summary: Public marketplace listings + 4 themes + slug rules + AI generation + listing media.
---

# `@chthonicsystems/listings` / `Chthonic.Listings`

SEO-friendly public service-centre / marina / clinic / depot pages. 4 pre-built themes (Classic, Modern, Bold, Elegant). Anonymous + authenticated users land on them; templates render client-side via LiquidJS in iframes.

## Purpose

- Tenant has a public listing at `/listing/{slug}` with custom theme + branding.
- Visitors discover, see ratings, browse services + photos, click "Book" / "Estimate" / "Favorite" / "Review".
- Sister-products' listings work cross-product (MarineDeck marina listings, PetCare clinic listings, FlowLift depot listings).

## Public surface

### .NET

| Type | Role |
|---|---|
| `IListingService` | Listing CRUD |
| `ListingTemplateRegistry` | Theme registry + feature-flag filtering |
| Slug generation + uniqueness | Reserved-words check, lowercase-hyphenated |
| `MapListingEndpoints` (admin) + `MapPublicListingEndpoints` (anonymous) | `/api/systems/my-system/listing` + `/api/listing/{slug}` |
| `services.AddChthonicListings(config)` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<ListingDesignerShell>` | Admin UI |
| `<PublicListingPage>` | Public renderer |
| `<IsolatedPreview>` | Preview iframe |

## Schema

```
system_listing
  system_listing_id  int PK
  system_id          int FK
  slug               varchar UNIQUE     # lowercase-hyphenated, max 100
  template_name      varchar            # 'classic', 'modern', 'bold', 'elegant', 'ai-v123'
  active_ai_artifact_id int FK?         # for AI-generated themes (live version)
  custom_settings    json               # labels, colors, branding
  is_published       bool
  created_at         datetime

system_listing_media
  media_id           int PK
  system_listing_id  int FK
  file_id            int FK → @chthonic/files
  display_order      int
  caption            varchar?
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/templating` | Liquid + iframe isolation |
| `@chthonic/files` | Listing photos |
| `@chthonic/ai` | AI-generated custom themes |

## Extension points

| Hook | Use |
|---|---|
| Per-product theme | Add as 5th theme drop-in |
| `ListingTemplateAI`, `ListingTemplateBold`, etc. feature flags | Per-tier theme availability |
| Slug rules | Reserved-words list customisable |

## Consuming this library

```csharp
builder.Services.AddChthonicListings(builder.Configuration);
app.MapListingEndpoints();
app.MapPublicListingEndpoints();
```

```tsx
import { ListingDesignerShell, PublicListingPage } from '@chthonicsystems/listings';
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`marketplace-listings.md`](marketplace-listings.md), [`four-themes.md`](four-themes.md), [`slug-rules.md`](slug-rules.md), [`ai-generation.md`](ai-generation.md), [`listing-media.md`](listing-media.md), [`public-listing-page.md`](public-listing-page.md).
- Library repo: [chthonicsystems/listings](https://github.com/chthonicsystems/listings).
- [RFC 0014](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0014-marketplace-listings-portability.md).
