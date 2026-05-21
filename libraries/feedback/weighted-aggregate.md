---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, aggregate, rating]
summary: Weighted rating aggregator — internal × 1.0, Google × 0.8.
---

# Weighted aggregate

The default `WeightedRatingAggregator` combines internal + Google reviews into a single average:

```
weight = (internal_count × 1.0) + (google_count × 0.8)
sum    = (internal_sum × 1.0) + (google_sum × 0.8)
average = sum / weight
```

Internal reviews weighted higher because they're collected directly + can be moderated; Google reviews are external input.

## Surface on public listing

```liquid
<div class="rating">
  ★ {{ rating | round: 1 }} ({{ total_reviews }} reviews)
</div>
```

`rating` and `total_reviews` come from the aggregate.

## Customising weights

```csharp
public class CustomAggregator : IRatingAggregator
{
    public double Aggregate(IList<Review> @internal, IList<GoogleReview> google)
    {
        // Internal × 1.5 (prefer first-party); Google × 0.5
        var weight = (@internal.Count * 1.5) + (google.Count * 0.5);
        var sum = @internal.Sum(r => r.Rating * 1.5) + google.Sum(r => r.Rating * 0.5);
        return weight == 0 ? 0 : sum / weight;
    }
}
```

## Edge cases

- 0 internal + 0 Google → return 0; UI hides rating display.
- 1 internal × 5★ + 0 Google → returns 5.0.
- All reviews identical → returns that rating.

## Related

- [`internal-reviews.md`](internal-reviews.md), [`google-reviews.md`](google-reviews.md).
