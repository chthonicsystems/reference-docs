---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, architecture]
summary: Feedback internals — internal reviews, Google Places cache, weighted aggregator.
---

# Architecture

```
src/Chthonic.Feedback/
├── Domain/Review.cs, GoogleReviewCache.cs
├── Configuration/, Migrations/
├── Services/
│   ├── IReviewService.cs / ReviewService.cs
│   ├── IGoogleReviewService.cs / GoogleReviewService.cs
│   ├── IRatingAggregator.cs / WeightedRatingAggregator.cs
│   └── GooglePlacesClient.cs
├── Endpoints/
└── ServiceCollectionExtensions.cs
```

## Internal review CRUD

`IReviewService.CreateAsync(systemId, userId, rating, body)` — auth-gated to customer users with confirmed booking/job history. The library checks via consumer-supplied access provider (consumer port).

## Google Places cache

24h TTL. On read miss, hits Google Places API + writes cache. Stale cache served on API error (graceful degradation).

## Weighted aggregator

```csharp
public class WeightedRatingAggregator : IRatingAggregator
{
    public double Aggregate(IList<Review> internal_, IList<GoogleReview> google)
    {
        var weight = (internal_.Count * 1.0) + (google.Count * 0.8);
        var sum = internal_.Sum(r => r.Rating * 1.0) + google.Sum(r => r.Rating * 0.8);
        return weight == 0 ? 0 : sum / weight;
    }
}
```

Override per-product if needed.

## Tests

`ReviewServiceTests`, `GoogleReviewServiceTests` (Google Places mocked), `WeightedRatingAggregatorTests`.

## Related

- [`internal-reviews.md`](internal-reviews.md), [`google-reviews.md`](google-reviews.md), [`weighted-aggregate.md`](weighted-aggregate.md).
