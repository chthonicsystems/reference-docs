---
library: ui
version: 0.1.0
related-rfcs: [0017]
last-verified: 2026-05-22
tags: [ui, primitives]
summary: app-* primitive components — cards, modals, toasts, fields, search, filter pills.
---

# `app-*` primitives

Every shared UI shape ships as an `app-*` prefixed class + a React component wrapper.

## Cards

| Class / component | Use |
|---|---|
| `.app-card` / `<AppCard>` | Base card (rounded 12px, shadow, padding 14-18px) |
| `.entity-card` / `<EntityCard>` | List + hero variants (5a, 5b) |
| `.app-view-card` / `<ViewCard>` | Flat detail card (no shadow) |
| `.md3-card-elevated` | Composed by `.entity-card-list` |

## Modals

| Class / component | Use |
|---|---|
| `.app-modal-overlay` + `.app-modal` / `<AppModal>` | Inline overlay modal (replaces IonModal) |
| `.app-modal-header`, `.app-modal-body`, `.app-modal-actions` | 3-region structure |
| `.app-confirm` modifier | Confirm-delete shorter variant |
| `.app-modal--wide` | Up to 1100px (preview-style) |
| `.app-modal--fullscreen` | 95vw × 95vh (split editors) |

## Toasts

| Class / component | Use |
|---|---|
| `.app-toast` / `<AppToast>` | Base |
| `.app-toast-success` / `.app-toast-danger` / `.app-toast-warning` | 2s / 3s / persistent |

## Form fields

| Class / component | Use |
|---|---|
| `.app-field` / `<AppField>` | Wrap label + native input + hint + error |
| `.app-error` / `<FormError>` | Inline validation render with `role="alert"` |
| `.app-hint` | Below-input hint copy |
| `.app-toggle-switch` / `<AppToggle>` | 44×24 toggle |
| `.app-search` / `<AppSearchInput>` | Pill-shaped search input |
| `.app-filter-pills` / `<AppFilterPills>` | 2-4 mutually-exclusive filters |
| `.app-field-radio-list`, `.app-field-checkbox-row`, `.app-field-compact` | Dynamic field variants |

## Empty states

| Class / component | Use |
|---|---|
| `.app-empty` / `<AppEmptyState>` | Big emoji + title + body + actions row |

## Buttons

`md3-button-*` classes (filled / outlined / tonal / text / compact / danger / warn / success). React renders as native `<button>` not `IonButton`.

## Action menus

| Class / component | Use |
|---|---|
| `.app-action-menu-overlay` + panel / `<AppActionMenu>` | Bottom-sheet on mobile, centred panel desktop |
| `.app-action-menu-item-danger` modifier | Destructive variant |

## Related

- [`five-page-patterns.md`](five-page-patterns.md), [`md3-tokens.md`](md3-tokens.md).
