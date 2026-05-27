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

> **Note for the F15 implementer (RFC 0036 — comeback-rate report).**
> The comeback-rate metric is a different kind of weighted aggregate
> from the review-rating one above — but the principle (weighted union
> of two distinct signal sources) is similar. F15 unions:
>
> 1. **`Job.ParentJobId`** — explicit user-asserted comeback link
>    captured at job creation or via the comeback PATCH endpoint.
>    Lives in `@chthonic/work` v0.7.0+; see
>    [`libraries/work/comeback-linkage.md`](../work/comeback-linkage.md).
> 2. **`JobReopen` audit rows** — admin reopened a Closed job back to
>    InProgress. TT-side entity introduced in PR 19 / RFC 0022 § 13.
>
> Don't compute the metric from a single source — the rework rate will
> be biased. The dual-signal contract is documented in detail in
> [`libraries/work/comeback-linkage.md` § Relationship to JobReopen](../work/comeback-linkage.md#relationship-to-jobreopen).
