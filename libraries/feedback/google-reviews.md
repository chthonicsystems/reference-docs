---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, google-places]
summary: Google Reviews — pull from Google Places API + 24h cache + graceful degradation.
---

# Google Reviews

Pulls recent reviews + aggregate rating from Google Places API for tenants with verified Google Business profiles.

## Setup

```bash
GOOGLE_PLACES_API_KEY=...
```

Tenant configures `system.google_place_id` in admin settings (or `system_configuration.google_place_id` — see consumer for storage).

## Cache

24h TTL by default. `google_review_cache` row per `(system_id, google_place_id)`. Override TTL:

```csharp
builder.Services.AddChthonicFeedback(opts => opts.GoogleReviewsCacheTtl = TimeSpan.FromHours(6));
```

## Read flow

```
GET /api/google-reviews?systemId=...

  1. Look up cache row.
  2. If cache fresh → return cached payload.
  3. If cache stale or missing → call Google Places API.
  4. On API success → write cache; return.
  5. On API failure → return stale cache if exists; else empty list.
```

## Feature flag

`GoogleReviews` flag (per-tenant via tier_feature + feature_override). When disabled, `IGoogleReviewService.GetCachedAsync` returns empty list immediately without hitting cache.

## Liquid variable

Public listings expose `google_place_id` (read-only) + `google_reviews` array via Liquid context.

## Related

- [`internal-reviews.md`](internal-reviews.md), [`weighted-aggregate.md`](weighted-aggregate.md).
