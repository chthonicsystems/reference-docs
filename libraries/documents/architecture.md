---
library: documents
version: 0.1.0
related-rfcs: [0012]
last-verified: 2026-05-22
tags: [documents, architecture]
summary: Documents internals — Common base classes + per-type concretes for 4 doc types.
---

# Architecture

```
src/Chthonic.Documents/
├── Common/
│   ├── TypeTemplateContext.cs
│   ├── TypeLiquidRenderer.cs
│   ├── TypeTemplateRegistry.cs
│   ├── TypeTemplateContextBuilder.cs
│   └── GotenbergPdfRenderer.cs
├── JobCardTemplate*/      # per-type concrete classes
├── InvoiceTemplate*/
├── EstimateTemplate*/
├── ServiceHistoryTemplate*/
├── Templates/             # 4 themes × 4 doc types = 16 base templates (Liquid + CSS)
├── AiTemplate/            # per-type AI tool executors + system prompts
├── Endpoints/
└── ServiceCollectionExtensions.cs
```

## Pipeline

```mermaid
graph LR
    A[Endpoint: render invoice X]
    B[InvoiceTemplateContextBuilder.Build]
    C[InvoiceLiquidRenderer.Render]
    D[GotenbergPdfRenderer]
    E[PDF bytes]

    A --> B --> C --> D --> E
```

`{Type}TemplateContext` carries the typed data. `{Type}LiquidRenderer` runs Liquid against it. `GotenbergPdfRenderer` POSTs the rendered HTML to Gotenberg. PDF returned.

## Tests

Per-type context-builder tests (real + sample data). Renderer smoke tests (Liquid compiles). Library-level Gotenberg integration test mocks the sidecar.

## Related

- [`liquid-pipeline.md`](liquid-pipeline.md), [`gotenberg-pdf.md`](gotenberg-pdf.md), [`four-themes.md`](four-themes.md).
