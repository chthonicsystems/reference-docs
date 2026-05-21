---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, md3, tokens]
summary: MD3 token layer — colour, typography, shape, elevation as CSS custom properties.
---

# MD3 tokens

The library ships the full Material Design 3 token layer as CSS custom properties.

## Colour tokens

```css
:root {
  --md-sys-color-primary: #1976d2;
  --md-sys-color-on-primary: #fff;
  --md-sys-color-surface: #fdfcff;
  --md-sys-color-surface-container: #f0f0f7;
  --md-sys-color-on-surface: #1a1c1e;
  --md-sys-color-on-surface-variant: #43474e;
  --md-sys-color-outline: #73777f;
  --md-sys-color-outline-variant: #c3c6cf;
  --md-sys-color-success: #2e7d32;
  --md-sys-color-error: #ba1a1a;
  --md-sys-color-primary-container: #d1e4ff;
  /* ... 30+ tokens total */
}
```

## Typography

15 styles in the MD3 scale:

```
md3-display-large        57px / 400
md3-display-medium       45px / 400
md3-display-small        36px / 400
md3-headline-large       32px / 400
md3-headline-medium      28px / 400
md3-headline-small       24px / 400
md3-title-large          22px / 500
md3-title-medium         16px / 500
md3-title-small          14px / 500
md3-body-large           16px / 400
md3-body-medium          14px / 400
md3-body-small           13px / 400
md3-label-large          14px / 500
md3-label-medium         12px / 500
md3-label-small          11px / 500 uppercase
```

Use the class. Never set `font-size` ad-hoc.

## Shape tokens

```css
--md-sys-shape-corner-card: 12px;
--md-sys-shape-corner-input: 8px;
--md-sys-shape-corner-button: 999px;
--md-sys-shape-corner-chip: 999px;
```

## Entity colour groups

```css
--color-entity-operations: #006bb4;
--color-entity-financial: #2e7d32;
--color-entity-scheduling: #e65100;
--color-entity-neutral: #8d6e63;
```

## Related

- [`brand-tokens.md`](brand-tokens.md), [`app-primitives.md`](app-primitives.md).
