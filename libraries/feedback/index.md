---
library: feedback
package-nuget: Chthonic.Feedback
package-npm: '@chthonicsystems/feedback'
version: 0.1.0
related-rfcs: [0015]
related-libs: [tenant, parties, listings]
last-verified: 2026-05-22
tags: [communications, reviews, google-places]
summary: Internal customer reviews + Google Reviews integration + weighted aggregate ratings.
---

# `@chthonicsystems/feedback` / `Chthonic.Feedback`

Customer reviews — internal (collected via the platform) + external (pulled from Google Places). Combined for public listing display.

## Purpose

Public listings need ratings + recent reviews to convert visitors. Some tenants have years of Google reviews + want them surfaced; new tenants want internal reviews with no Google presence. This library handles both.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IReviewService` | Internal-review CRUD + aggregate |
| `IGoogleReviewService` | Pull from Google Places + cache |
| `IRatingAggregator` | Weighted aggregate (internal + Google) |
| `MapFeedbackEndpoints` | `/api/reviews/*`, `/api/google-reviews/*` |
| `services.AddChthonicFeedback(config)` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<ReviewsPanel>` | Display reviews on public listings |
| `<WriteReviewForm>` | Authenticated customers write reviews |
| `useReviews` hook | Paginated review reads |

## Schema

```
review
  review_id     int PK
  system_id     int
  user_id       int FK?    (customer-portal user; null for anonymous import)
  rating        tinyint    1-5
  body          text?
  created_at    datetime
  is_visible    bool       moderation flag

google_review_cache
  cache_id      int PK
  system_id     int
  google_place_id varchar
  fetched_at    datetime
  ttl_seconds   int        default 86400
  payload       json       parsed Google Places API response
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/parties` | Customer / user FK |
| `@chthonic/listings` | Reviews surface on public listings |
| Google Places API | External reviews |

## Extension points

| Hook | Use |
|---|---|
| Feature flag `GoogleReviews` | Enable/disable Google Places integration per tenant |
| `IRatingAggregator` override | Custom weighting (default: internal × 1.0, Google × 0.8) |
| Cache TTL | Override default 24h via DI options |

## Consuming this library

```csharp
builder.Services.AddChthonicFeedback(builder.Configuration);
app.MapFeedbackEndpoints();
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`internal-reviews.md`](internal-reviews.md), [`google-reviews.md`](google-reviews.md), [`weighted-aggregate.md`](weighted-aggregate.md).
- Library repo: [chthonicsystems/feedback](https://github.com/chthonicsystems/feedback).
- [RFC 0015](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0015-feedback-and-reviews.md).
