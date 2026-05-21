---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, extension-points]
summary: Extension points — IRatingAggregator, IReviewAccessProvider, cache TTL.
---

# Extension points

| Hook | Use |
|---|---|
| `IRatingAggregator` | Custom weighting (default: internal × 1.0, Google × 0.8) |
| `IReviewAccessProvider` | Decide which users can write reviews |
| Cache TTL | Override default 24h on Google Reviews |
| `GoogleReviews` feature flag | Per-tenant enable/disable |

## Custom aggregator

```csharp
public class FlatAggregator : IRatingAggregator
{
    public double Aggregate(IList<Review> internal_, IList<GoogleReview> google)
        => (internal_.Concat<IReview>(google)).Average(r => r.Rating);
}
builder.Services.AddSingleton<IRatingAggregator, FlatAggregator>();
```

## Review access provider

```csharp
public class TTReviewAccessProvider : IReviewAccessProvider
{
    public Task<bool> CanWriteAsync(int userId, int systemId)
    {
        // Only customers with at least one Completed Job can review
        return _db.Jobs.AnyAsync(j => j.SystemId == systemId &&
                                     j.Customer.UserId == userId &&
                                     j.Status == JobStatus.Completed);
    }
}
```

## Related

- [`weighted-aggregate.md`](weighted-aggregate.md), [`internal-reviews.md`](internal-reviews.md).
