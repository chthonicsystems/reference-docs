---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, marketplace]
summary: Public marketplace listings — anonymous-readable tenant pages with custom branding.
---

# Marketplace listings

Public-facing tenant pages. Anonymous + authenticated users can view; only authenticated customers can take actions (book, request estimate, write review, favorite).

## URL shape

```
/listing/{slug}                 # public page
/listing/{slug}?action=book     # deep-link to book action
/listing/{slug}?action=estimate
/listing/{slug}?action=favorite
/listing/{slug}?action=review
```

For unauthenticated users, action links redirect via `/login?redirect=/listing/{slug}&action=book`.

## Cross-product

- TT — service-centre listings (auto repair shops, motorbike service centres).
- MarineDeck — marina listings (slip booking, hull cleaning).
- FlowLift — depot listings (forklift hire, servicing).
- PetCare — clinic listings (vet appointments).

Each product overrides 4 brand-token CSS variables; the same listing engine renders.

## SEO

Server-side render → static HTML at `/listing/{slug}`. `og:` meta tags populate from listing data. `sitemap.xml` lists every published listing.

## Liquid context

```
listing: { name, description, hero_image_url, ... }
system:  { name, contact, working_hours, ... }
services: [list]
products: [list]
reviews: [internal + Google merged]
google_place_id: ...
google_reviews: [...]
```

## Related

- [`four-themes.md`](four-themes.md), [`public-listing-page.md`](public-listing-page.md), [`slug-rules.md`](slug-rules.md).
