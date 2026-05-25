---
library: views
version: 0.5.0
related-rfcs: [0010]
last-verified: 2026-05-22
tags: [views, ui, screen-sections-renderer]
summary: <ScreenSectionsRenderer> — dynamic field renderer that respects view resolution + role visibility.
---

# `<ScreenSectionsRenderer>`

The primary UI component. Renders all fields visible to the current (user × entity status) for a given entity, grouped into screens + sections per the resolved view.

## Usage

```tsx
import { setHttpAdapter, ScreenSectionsRenderer } from '@chthonicsystems/views';

setHttpAdapter(httpService);   // bootstrap once at app start

<ScreenSectionsRenderer
  entityType="Job"
  entityId={jobId}
  systemId={systemId}
  userId={userId}
  status={job.status}            // gates status-specific fields
  onFieldChange={(field, value) => /* react to field changes */}
  readOnly={false}
/>
```

## Render tree

```
<ScreenSectionsRenderer>
└── per-screen <ScreenGroup>
    └── per-section <Section>
        ├── header (chevron + icon + title)
        └── body
            └── per-field <FieldRenderer>
                ↳ <TextField> | <NumericField> | <DateField> | <CheckboxField> |
                  <OptionsField> | <ComboField> | <MultiValueOptionsField>
```

## Resolution flow

1. Component mounts → calls `GET /api/system-views?entityType=Job&userId=...` → resolves the active view.
2. For the active view, fetches `GET /api/custom-fields/{viewId}` → field definitions.
3. Filters fields:
   - By `system_entity_field_role` rows matching user's roles.
   - By `system_entity_field_status` rows matching `status` prop.
4. Fetches existing values: `GET /api/entity-field-values?entityType=Job&entityId={jobId}`.
5. Renders sections + fields.

## Editing

`onFieldChange` fires per field change. Persistence is debounced (500ms by default) — the component PUTs to `/api/entity-field-values`.

## Inline sections

A section with `inline: true` renders fields flat (no card wrapper). Used for screens that need single-block layouts.

## Performance

For an entity with 50 visible fields, the component:

- 1 view-resolve request.
- 1 field-definition request.
- 1 values request.
- = 3 requests on mount (memoised).

Subsequent edits → 1 PUT per field-change (debounced).

## Related

- [`auto-providers.md`](auto-providers.md) — auto-section integration.
- [`extension-points.md`](extension-points.md) — http adapter setup.
- [`custom-fields.md`](custom-fields.md), [`entity-field-discriminator.md`](entity-field-discriminator.md).
- [`tolerance-bounds.md`](tolerance-bounds.md) — v0.8.12 lifted operational-mode tolerance hint.

## v0.8.13 — `renderQcAttachmentSlot` prop (PR 05 / RFC 0024 § 12 Amendment 1)

Hosts can now mount their own evidence slot for `boolean-attachment`
/ `number-attachment` QC fields via:

```tsx
<ScreenSectionsRenderer
  kind="qc"
  qcResults={qcResultsWithIds}
  renderQcAttachmentSlot={({ field, qcSignoffItemResultId }) => (
    <QcEvidenceSlot field={field} qcSignoffItemResultId={qcSignoffItemResultId} />
  )}
/>
```

`qcResults` entries gain an optional `qcSignoffItemResultId` field
that the renderer forwards to the prop. When the prop is omitted the
renderer falls back to the empty placeholder div from v0.8.12 (back-
compat preserved).

See [`../files/qc-evidence.md`](../files/qc-evidence.md) for the TT
consumer pattern that wires this prop to `<FileGallery filterBySubEntity>`
and `useMediaCapture`.
