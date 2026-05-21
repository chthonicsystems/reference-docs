---
library: listings
version: 0.1.0
related-rfcs: [0014]
last-verified: 2026-05-22
tags: [listings, slug, seo]
summary: Slug rules — lowercase, hyphenated, max 100 chars, unique, reserved-words-rejected.
---

# Slug rules

`SystemListing.Slug` is the URL fragment in `/listing/{slug}`. Strict rules:

- **Lowercase** only.
- **Hyphen-separated** words (no underscores, spaces, dots).
- **Max 100 characters**.
- **Unique** within the registry; library appends `-2`, `-3`, ... on collision.
- **Rejected reserved words**: `login`, `signup`, `admin`, `api`, `listing`, `home`, `dashboard`, `profile`, `settings`, `config`, `config-hub`, `images`, `assets`, `static`.

## Generation

```csharp
public class SlugGenerator
{
    public string Generate(string businessName)
    {
        var slug = businessName.ToLowerInvariant()
            .Replace(" ", "-")
            .RemoveDiacritics()
            .Where(c => char.IsLetterOrDigit(c) || c == '-')
            .Take(100);
        return EnsureUnique(slug);
    }
}
```

## Reserved words

Customisable via DI:

```csharp
builder.Services.AddChthonicListings(opts =>
{
    opts.AdditionalReservedSlugs = new[] { "about", "contact", "help" };
});
```

Default list always blocks anything that would collide with platform routes.

## Open-redirect prevention

Action redirects (`/login?redirect=...`) only accept relative URLs. The query parser rejects `redirect=https://evil.com`.

## Related

- [`marketplace-listings.md`](marketplace-listings.md), [`extension-points.md`](extension-points.md).
