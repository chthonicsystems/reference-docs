---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, architecture]
summary: UI library internals — CSS file ownership, primitive promotion rules.
---

# Architecture

```
npm/src/
├── index.ts                  # public re-exports
├── components/
│   ├── MD3AppBar.tsx
│   ├── AppCard.tsx, AppModal.tsx, AppToast.tsx, ...
│   ├── StickyFooter.tsx, AppActionMenu.tsx
│   ├── EntityCard.tsx, MgmtCardList.tsx
│   ├── customer-portal/CustomerPortalShell.tsx, MarketingHeader.tsx
│   └── ...
├── styles/                   # CSS source
│   ├── app-components.css    # widest-scope app-* primitives
│   ├── md3-tokens.css        # MD3 token layer
│   ├── md3-typography.css    # MD3 type scale
│   ├── md3-buttons.css, md3-cards.css, md3-fab.css, md3-dialogs.css
│   ├── md3-effects.css       # elevation + motion + micro-interactions
│   ├── entity-cards.css      # 5a + 5b primitives
│   ├── management-cards.css  # mgmt-card-* composition
│   ├── create-form-cards.css # create-form-card-*
│   ├── detail-tables.css, badges.css, chthonic-logo.css
│   ├── variables.css         # Ionic theme + brand tokens
│   ├── design-tokens.css     # generic CSS custom properties
│   ├── md3-utilities.css, utilities.css
│   └── global.css            # SINGLE entry point: imports every other CSS file
└── scripts/copy-css.js       # postbuild — copies CSS into dist/
```

## Single global entry

Consumers import once:

```tsx
import '@chthonicsystems/ui/dist/styles.css';
```

…which is `global.css` with `@import` of every module. App-level `App.tsx` imports nothing else.

## Primitive promotion rule

From the platform CSS architecture rule (also documented in TT steering ui.md):

> If a rule starts being needed by a 2nd consumer, keep it page-local.
> At the **3rd consumer**, promote it into a `theme/` module.

Library v0.1.0 ships every rule that has 3+ consumers.

## Tests

Vitest snapshot tests for primitive components. Cross-product regression test: render each canonical page pattern; compare to baseline screenshots.

## Related

- [`md3-tokens.md`](md3-tokens.md), [`app-primitives.md`](app-primitives.md), [`brand-tokens.md`](brand-tokens.md).
