---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/listings`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.Listings" Version="0.1.0" />
```

```json
"@chthonicsystems/listings": "0.1.0"
```

## 2. Register DI

```csharp
using Chthonic.Listings;
builder.Services.AddChthonicListings(builder.Configuration);
app.MapListingEndpoints();
app.MapPublicListingEndpoints();
```

## 3. Configure feature flags

Per-tier flag rows determine which themes are available:

```sql
INSERT INTO tier_feature (tier_id, feature_name, bool_value)
SELECT tier_id, 'ListingTemplateModern', name IN ('Standard', 'Premium') FROM tier;

INSERT INTO tier_feature (tier_id, feature_name, bool_value)
SELECT tier_id, 'ListingTemplateBold', name = 'Premium' FROM tier;
```

## 4. Frontend

```tsx
import { ListingDesignerShell, PublicListingPage } from '@chthonicsystems/listings';
<ListingDesignerShell systemId={systemId} />
```

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`four-themes.md`](four-themes.md).
