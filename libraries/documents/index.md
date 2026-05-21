---
library: documents
package-nuget: Chthonic.Documents
package-npm: '@chthonicsystems/documents'
version: 0.1.0
related-rfcs: [0012]
related-libs: [tenant, templating, billing, ai, files]
last-verified: 2026-05-22
tags: [feature, documents, pdf, gotenberg, four-themes]
summary: Liquid + CSS + Gotenberg PDF pipeline + 4 themes + Document Designer + AI generation.
---

# `@chthonicsystems/documents` / `Chthonic.Documents`

Per-product document templating + PDF rendering. Four document types (Job Card, Invoice, Estimate, Service History) share one pipeline + 4 pre-built themes (Classic, Modern, Bold, Elegant).

## Purpose

- One Liquid + CSS + Gotenberg pipeline.
- 4 doc types share rendering machinery via `Common/` base classes.
- Per-doc-type `TemplateContext` builders + registries.
- 4 pre-built themes per type + per-product AI generation.
- Document Designer UI shell (admin picks theme + edits labels + previews PDF).
- `<DocumentDesignerShell>` (Option C — feature library hosts feature UI).

## Public surface

### .NET

| Type | Role |
|---|---|
| `IDocumentRenderer` | Liquid render + Gotenberg PDF |
| `GotenbergPdfRenderer` | Wraps Gotenberg sidecar (HTTP) |
| `Common/` base classes | `TypeTemplateContext`, `TypeLiquidRenderer`, `TypeTemplateRegistry`, `TypeTemplateContextBuilder` |
| Per-type concretes (Job Card / Invoice / Estimate / Service History) | Each ~4 small classes |
| `MapDocumentTemplateEndpoints` | `/api/{type}-templates/*` × 4 doc types |
| `services.AddChthonicDocuments(config)` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<DocumentDesignerShell>` | Admin UI — pick style, edit labels, preview |
| `<DocumentDesignerLanding>` | Default landing card |
| `<AiDocumentGenerationPanel>` | AI prompt panel for doc generation |

## Schema

Documents themselves don't have a primary schema; the library renders against entities owned by other libraries (`Job`, `Invoice`, `Estimate`). Per-tenant document configuration lives on `system_configuration` extension columns owned by the consumer.

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id + config |
| `@chthonic/templating` | Liquid pipeline |
| `@chthonic/billing` | Invoice / Estimate entities |
| `@chthonic/ai` | AI generation |
| `@chthonic/files` | Generated PDF storage |
| Gotenberg (sidecar) | HTML → PDF |

## Extension points

| Hook | Use |
|---|---|
| Per-product theme | Extend the 4 default themes with custom Liquid + CSS |
| AI tool executor (per type) | `Ai{Type}TemplateToolExecutor` for AI generation |
| Custom template context | Override `TypeTemplateContextBuilder` per consumer |

## Consuming this library

```csharp
builder.Services.AddChthonicDocuments(builder.Configuration);
app.MapDocumentTemplateEndpoints();
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`liquid-pipeline.md`](liquid-pipeline.md), [`gotenberg-pdf.md`](gotenberg-pdf.md), [`four-themes.md`](four-themes.md), [`document-designer-shell.md`](document-designer-shell.md), [`ai-generation.md`](ai-generation.md).
- Library repo: [chthonicsystems/documents](https://github.com/chthonicsystems/documents).
- [RFC 0012](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0012-document-designer-portability.md).
