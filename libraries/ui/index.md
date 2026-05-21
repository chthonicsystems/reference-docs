---
library: ui
package-nuget: Chthonic.UI
package-npm: '@chthonicsystems/ui'
version: 0.1.0
related-rfcs: [0017]
related-libs: [locale]
last-verified: 2026-05-22
tags: [ui, design-system, md3, foundational]
summary: Foundational design system — MD3 + app-* primitives + 5 page patterns + customer portal layout + brand tokens.
---

# `@chthonicsystems/ui` / `Chthonic.UI`

Foundational design system. MD3 token + `app-*` primitives + 5 canonical page patterns. **Foundational only** — feature-specific shells (ConfigHub, Document Designer, AI panels) live in their feature libraries (Option C).

## Purpose

- Single design system across every product.
- MD3 (Material Design 3) tokens as CSS custom properties.
- `app-*` primitives (cards, modals, toasts, form fields, toggles, filter pills, empty states, search inputs, inline FAB, save buttons, sticky footers).
- 5 canonical page patterns: list-row richer card, detail-hero richer card, dynamic screens + sections, create/edit page skeleton, inline validation.
- Customer portal layout primitives.
- 4 brand tokens — products override these CSS custom properties for visual identity.

## Public surface

### .NET

| Type | Role |
|---|---|
| (none) | UI is npm-only |

### npm

| Export | Role |
|---|---|
| `<MD3AppBar>` | Top chrome (title, back, slots) |
| `<AppField>`, `<FormError>`, `<AppSaveButton>` | Form primitives |
| `<AppCard>`, `<AppModal>`, `<AppToast>`, `<AppEmptyState>` | Card/modal/toast/empty primitives |
| `<StickyFooter>`, `<AppActionMenu>` | Footer + kebab menu |
| `<EntityCard>`, `<MgmtCardList>` | List + hero card primitives (canonical patterns 5a, 5b) |
| `<AppFilterPills>`, `<AppSearchInput>`, `<AppInlineFab>` | List page chrome (5A) |
| `<IconSelector>`, `<AppTabs>` | Icon picker, tab bar |
| Customer portal primitives (`<CustomerPortalShell>`, `<MarketingHeader>`) | Customer-facing layout |
| Theme CSS files | `app-components.css`, `md3-tokens.css`, `md3-typography.css`, `md3-buttons.css`, `md3-cards.css`, `md3-fab.css`, `md3-dialogs.css`, `md3-effects.css`, `entity-cards.css`, `management-cards.css`, `create-form-cards.css`, `detail-tables.css`, `badges.css`, `chthonic-logo.css` |

## Brand tokens

Per-product overrides via 4 CSS custom properties:

```css
:root {
  --brand-primary: #F9DC0A;            /* TT yellow; MarineDeck navy; etc. */
  --brand-on-primary: #000000;
  --brand-accent-customer: #00897B;
  --brand-accent-marketplace-bg: #1a1a2e;
}
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/locale` | `useFormatting()` consumed by some primitives |
| React 18+, Ionic 8+ (peer deps) | Renderer |

## Extension points

| Hook | Use |
|---|---|
| 4 brand tokens | Per-product visual identity |
| `<AppCard variant="...">` | Compositional variants |
| Add a new primitive | Promote on the third consumer (per CSS architecture rule) |

## Consuming this library

```tsx
import '@chthonicsystems/ui/dist/styles.css';   // imports all theme CSS

import { MD3AppBar, AppCard, AppField, StickyFooter } from '@chthonicsystems/ui';
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`md3-tokens.md`](md3-tokens.md), [`app-primitives.md`](app-primitives.md), [`five-page-patterns.md`](five-page-patterns.md), [`customer-portal-layout.md`](customer-portal-layout.md), [`brand-tokens.md`](brand-tokens.md).
- Library repo: [chthonicsystems/ui](https://github.com/chthonicsystems/ui).
- [RFC 0017](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0017-customer-portal-and-ui.md).
