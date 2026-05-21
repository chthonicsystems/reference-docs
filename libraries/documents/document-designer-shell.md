---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, ui, designer]
summary: <DocumentDesignerShell> — admin UI for picking theme + editing labels + previewing PDFs.
---

# `<DocumentDesignerShell>`

Per Option C — the feature library hosts the feature UI shell. Admins navigate to `/document-designer/{type}` to customise the document.

## Component shape

```tsx
<DocumentDesignerShell
  type="invoice" | "estimate" | "jobcard" | "service-history"
  systemId={systemId}
/>
```

Internal layout:

```
┌─────────────────────────────────────────────┐
│ MD3AppBar: "Invoice Designer"               │
├──────────────────┬──────────────────────────┤
│ Sidebar          │ Preview iframe           │
│ - Theme picker   │ (live IsolatedTemplate-  │
│ - Labels editor  │  Preview reflecting     │
│ - Colors         │  current selections)     │
│ - View picker    │                          │
│ - AI panel       │                          │
└──────────────────┴──────────────────────────┘
```

## Endpoints used

```
GET /api/{type}-templates/list                # available themes
GET /api/{type}-templates/{name}/content      # template source
GET /api/{type}-templates/preview             # live HTML preview
GET /api/{type}-templates/preview-pdf         # binary PDF preview
PUT /api/{type}-templates/set-template
PUT /api/{type}-templates/set-settings
```

## Live preview

Edits debounce → `GET /preview` → render in `<IsolatedTemplatePreview>` iframe. PDF preview is on-demand (`/preview-pdf`).

## AI generation panel

Embedded `<AiDocumentGenerationPanel type="invoice">` lets admins generate a custom theme via prompt. See [`ai-generation.md`](ai-generation.md).

## Related

- [`four-themes.md`](four-themes.md), [`ai-generation.md`](ai-generation.md), [`liquid-pipeline.md`](liquid-pipeline.md).
