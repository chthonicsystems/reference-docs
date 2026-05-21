---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, public, anonymous]
summary: <PublicListingPage> — anonymous-readable React component rendering /listing/{slug}.
---

# `<PublicListingPage>`

Renders the public-facing tenant page at `/listing/{slug}`. Anonymous + authenticated users land here.

## Endpoint

```
GET /api/listing/{slug}
  → { listing, system, services, products, reviews, googleReviews, theme, googlePlaceId }
```

Caching: `Cache-Control: max-age=60` for anonymous users; `no-cache` for authenticated. Nginx rate-limit: 30 req/min/ip prod, 600 req/min/ip beta.

## Component

```tsx
import { PublicListingPage } from '@chthonicsystems/listings';

<PublicListingPage slug={slug} />
```

Internally:

1. Fetches listing data.
2. Fetches template content (cached `max-age=3600`).
3. Renders Liquid template inside `<IsolatedPreview>` iframe.
4. Wires action links (Book / Estimate / Favorite / Review).

## Action redirects

Unauthenticated user clicks "Book" → redirect to `/login?redirect=/listing/{slug}&action=book&business={systemId}`. Open-redirect prevention: only relative `redirect` URLs accepted.

Authenticated user clicks "Book" → routes to `/booking/create?systemId=...`.

## Sitemap

```
GET /api/sitemap.xml
```

Returns every published listing's URL + last-modified. Submits to Google / Bing for SEO.

## Cross-product

The component is product-agnostic. MarineDeck mounts the same `<PublicListingPage>`; only the resolved theme + content differs.

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`four-themes.md`](four-themes.md), [`slug-rules.md`](slug-rules.md).
