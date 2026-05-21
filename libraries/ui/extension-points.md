---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, extension-points]
summary: Extension points — brand tokens override + primitive promotion rule.
---

# Extension points

| Hook | Use |
|---|---|
| 4 brand tokens (`--brand-*`) | Per-product visual identity |
| `<AppCard variant="...">` | Compositional variants |
| Promote-on-third-consumer | Rule for adding new primitives |

## Brand override (most common extension)

```css
:root {
  --brand-primary: #...;
  --brand-on-primary: #...;
  --brand-accent-customer: #...;
  --brand-accent-marketplace-bg: #...;
}
```

That's the entire per-product UI customisation in v0.1.0.

## Adding a new primitive

The CSS architecture rule (per TT steering):

1. Need a rule for one page → keep it page-local with a unique prefix (e.g. `.job-detail-stack`).
2. Second consumer → keep it page-local; don't fork.
3. Third consumer → promote into `app-components.css` with a generic `app-*` prefix.

Follow this rule when contributing upstream.

## Variants

Most primitives accept a `variant` prop for compositional changes:

```tsx
<AppCard variant="elevated">     {/* default; shadow */}
<AppCard variant="flat">          {/* no shadow */}
<AppCard variant="hero">          {/* large heading + chips + actions */}
```

## Related

- [`brand-tokens.md`](brand-tokens.md), [`app-primitives.md`](app-primitives.md).
