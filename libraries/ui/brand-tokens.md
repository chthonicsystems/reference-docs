---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, brand, tokens]
summary: Four brand tokens — the only per-product UI customisation.
---

# Brand tokens

The four CSS custom properties products override for visual identity. Everything else inherits.

## Tokens

```css
:root {
  --brand-primary: #F9DC0A;            /* Primary CTA colour */
  --brand-on-primary: #000000;          /* Text on primary */
  --brand-accent-customer: #00897B;     /* Customer-facing accent */
  --brand-accent-marketplace-bg: #1a1a2e;  /* Marketplace header gradient */
}
```

## Per-product values

### TorqueTech (founding product)

```css
--brand-primary: #F9DC0A;            /* yellow */
--brand-on-primary: #000000;
--brand-accent-customer: #00897B;
--brand-accent-marketplace-bg: #1a1a2e;
```

### MarineDeck (marina management)

```css
--brand-primary: #1565C0;             /* navy */
--brand-on-primary: #ffffff;
--brand-accent-customer: #009688;     /* teal */
--brand-accent-marketplace-bg: #0d47a1;
```

### FlowLift (forklift fleet)

```css
--brand-primary: #FF6F00;             /* orange */
--brand-on-primary: #ffffff;
--brand-accent-customer: #00838F;     /* teal-cyan */
--brand-accent-marketplace-bg: #263238;
```

### PetCare OS (veterinary)

```css
--brand-primary: #7B1FA2;             /* purple */
--brand-on-primary: #ffffff;
--brand-accent-customer: #00897B;     /* teal */
--brand-accent-marketplace-bg: #4A148C;
```

## Override location

```css
/* web/src/brand-overrides.css */
:root {
  --brand-primary: #...;
  --brand-on-primary: #...;
  --brand-accent-customer: #...;
  --brand-accent-marketplace-bg: #...;
}
```

Imported AFTER `@chthonicsystems/ui/dist/styles.css` so the cascade picks up the override.

## Why four (not more)

Every other colour in the system uses MD3 semantic tokens (`--md-sys-color-*`). Those are platform-wide. Brand tokens cover the few places where products genuinely differ (yellow create button, navy marina hero, etc.).

Adding a 5th brand token requires an RFC amendment — the cap is intentional.

## Related

- [`md3-tokens.md`](md3-tokens.md), [`extension-points.md`](extension-points.md).
- [`platform/forking-a-library.md`](../../platform/forking-a-library.md) — last resort if 4 tokens are insufficient.
