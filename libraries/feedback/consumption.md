---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/feedback`

## 1. Add packages + configure

```xml
<PackageReference Include="Chthonic.Feedback" Version="0.1.0" />
```

```bash
GOOGLE_PLACES_API_KEY=...
```

## 2. Register DI

```csharp
builder.Services.AddChthonicFeedback(builder.Configuration);
app.MapFeedbackEndpoints();
```

## 3. Use in public listing renderer

```csharp
public async Task<ListingPageContext> BuildAsync(int systemId)
{
    var internalReviews = await _reviews.GetVisibleAsync(systemId, take: 10);
    var googleReviews = _featureFlags.IsEnabled("GoogleReviews", systemId)
        ? await _googleReviews.GetCachedAsync(systemId)
        : [];
    var rating = _aggregator.Aggregate(internalReviews, googleReviews);
    return new ListingPageContext { Reviews = internalReviews, GoogleReviews = googleReviews, Rating = rating };
}
```

## 4. Frontend — write review form

```tsx
import { WriteReviewForm } from '@chthonicsystems/feedback';
<WriteReviewForm systemId={systemId} userId={userId} onSubmit={...} />
```

## Related

- [`internal-reviews.md`](internal-reviews.md), [`google-reviews.md`](google-reviews.md).
