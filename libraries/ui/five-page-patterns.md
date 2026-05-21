---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, patterns, page-shapes]
summary: 5 canonical page patterns — list-row card, detail-hero, dynamic sections, create/edit, inline validation.
---

# Five canonical page patterns

Every new surface picks one. Don't invent a sixth.

## §5a — List-row richer card

Reference: TT `/jobs`, `/users`. Class vocabulary:

```
.entity-card-list
└── .md3-card-elevated
    ├── .mgmt-card-header
    │   ├── .mgmt-card-main-info
    │   └── .mgmt-card-badge-container
    │       └── .entity-card-chip(--<tone>)
    ├── .mgmt-card-info-row
    └── .mgmt-card-actions
```

Page chrome: `.app-search-row` + `.app-filter-pills` + `.app-empty*` + `.app-toast*`.

## §5b — Detail-hero richer card

Reference: TT `/jobs/:id`. Class vocabulary:

```
.entity-card.entity-card-hero.entity-card-non-clickable
├── .entity-card-header
│   ├── .entity-card-header-main
│   │   ├── .entity-card-headline.md3-title-large
│   │   └── .entity-card-chips
│   └── .entity-card-actions
└── .entity-card-meta
    └── .entity-card-meta-row
```

## §5c — Dynamic screens + sections

Reference: `<ScreenSectionsRenderer>` from `@chthonic/views`. Class vocabulary:

```
.app-screen-group
├── .app-screen-group-header
└── .app-screen-group-body
    └── .app-view-card.app-view-section
        ├── .app-view-section-header (button)
        └── .app-view-section-body
```

## §5d — Create / edit page skeleton

Reference: TT `/users/create`. Pattern:

```
<MD3AppBar>
<IonContent className="has-sticky-footer">
  <div style={{ padding: '16px 16px 96px 16px' }}>
    <FormError-bearing form>
  </div>
  <StickyFooter onSave={...} disabled={!valid || submitting} />
</IonContent>
```

Toast: scoped `<div className="app-toast app-toast-*">` with `role="status"`. 2000ms success / 3000ms danger / persistent warning.

## §5e — Inline validation

Reference: `UserForm` + `<FormError>` + `utils/passwordValidation.ts`. Pattern:

```tsx
const [errors, setErrors] = useState<Record<string, string>>({});
const validateX = (val) => setErrors(prev => ({ ...prev, x: ... }));

<AppField label="Email">
  <input value={email} onChange={...} onBlur={() => validateEmail(email)} />
  <FormError error={errors.email} />
</AppField>
```

## Related

- [`app-primitives.md`](app-primitives.md), [`brand-tokens.md`](brand-tokens.md).
