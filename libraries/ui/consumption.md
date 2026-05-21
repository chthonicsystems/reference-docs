---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/ui`

## 1. Add packages

```json
"@chthonicsystems/ui": "0.1.0"
```

## 2. Import CSS once

```tsx
// File: web/src/main.tsx (or App.tsx)
import '@chthonicsystems/ui/dist/styles.css';

// Optional: per-product brand overrides
import './brand-overrides.css';
```

## 3. Import primitives

```tsx
import {
  MD3AppBar,
  AppField,
  AppCard,
  AppModal,
  AppToast,
  AppEmptyState,
  StickyFooter,
  EntityCard,
  AppFilterPills,
} from '@chthonicsystems/ui';
```

## 4. Brand override

```css
/* web/src/brand-overrides.css */
:root {
  --brand-primary: #1565C0;            /* MarineDeck navy */
  --brand-on-primary: #ffffff;
  --brand-accent-customer: #009688;
  --brand-accent-marketplace-bg: #0d47a1;
}
```

That's it — the rest of MD3 + `app-*` rules pick up the brand colour automatically.

## Verification

- [ ] No raw hex colours in your app's CSS (besides brand-overrides).
- [ ] No ad-hoc `font-size` declarations.
- [ ] All cards / modals / toasts use `app-*` primitives.
- [ ] Pages match one of the 5 canonical patterns.

## Related

- [`brand-tokens.md`](brand-tokens.md), [`five-page-patterns.md`](five-page-patterns.md).
