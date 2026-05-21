---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, customer-portal, marketplace]
summary: Customer portal layout — separate from admin shell; teal accent; marketplace surface.
---

# Customer portal layout

A separate visual track for customer-facing surfaces. Same MD3 + `app-*` foundations + a teal customer accent + marketplace headers.

## Layout primitives

| Component | Use |
|---|---|
| `<CustomerPortalShell>` | Wraps customer-portal pages; sets teal accent + marketplace bg |
| `<MarketingHeader>` | Hero header used on listings + signup |
| `<CustomerTabBar>` | Bottom tab bar for customer mobile app |
| `<MyBookingsCard>`, `<MyJobsCard>` | Customer-side card variants |

## Distinction from admin shell

- Admin shell: `--brand-primary` (yellow on TT) for "create" CTAs.
- Customer portal: `--brand-accent-customer` (teal `#00897B`) for booking / favourite / review CTAs.

## Public listing layout

`<PublicListingPage>` from `@chthonic/listings` composes:

- `<MarketingHeader>` — gradient hero bg uses `--brand-accent-marketplace-bg`.
- Body inside `<IsolatedTemplatePreview>` iframe (CSS-isolated).
- Action chips at bottom for Book / Estimate / Favourite / Review.

## Customer app vs marketing

The customer mobile app reuses `<CustomerPortalShell>`. The marketing/listing surfaces reuse `<MarketingHeader>`. Both share the teal accent.

## Related

- [`brand-tokens.md`](brand-tokens.md), [`app-primitives.md`](app-primitives.md).
- [`libraries/listings/`](../listings/), [`libraries/booking/`](../booking/).
