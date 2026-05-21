---
library: documents
version: 0.1.0
related-rfcs: [0012, 0013]
related-libs: [ai]
last-verified: 2026-05-22
tags: [documents, ai, generation]
summary: AI-generated document themes — per-doc-type Ai{Type}TemplateToolExecutor + system prompt.
---

# AI generation

Each doc type has its own AI tool executor + system prompt. A 5th option alongside the 4 pre-built themes — admins generate a custom theme by typing a prompt.

## Per-type executors

```
Chthonic.Documents.AiTemplate/
├── AiJobCardTemplateToolExecutor.cs
├── AiInvoiceTemplateToolExecutor.cs
├── AiEstimateTemplateToolExecutor.cs
├── AiServiceHistoryTemplateToolExecutor.cs
└── Templates/
    ├── AiJobCardTemplateSystemPrompt.md          # embedded resource
    ├── AiInvoiceTemplateSystemPrompt.md
    ├── AiEstimateTemplateSystemPrompt.md
    └── AiServiceHistoryTemplateSystemPrompt.md
```

## Tools per executor

Same shape across all four types (4 tools each):

| Tool | Purpose |
|---|---|
| `render_html` | Generate HTML structure |
| `edit_css` | Generate/refine CSS |
| `suggest_color_scheme` | Pick brand-aware palette |
| `validate_output` | Self-check against `RenderedHtmlSecurityPolicy` |

## Endpoints (per type)

```
/api/systems/my-system/ai-{jobcard|invoice|estimate|service-history}/draft
/api/systems/my-system/ai-{type}/generate
/api/systems/my-system/ai-{type}/status
/api/systems/my-system/ai-{type}/save
/api/systems/my-system/ai-{type}/edit
```

Mirror shape of AI Listings.

## Frontend

```tsx
import { AiDocumentGenerationPanel } from '@chthonicsystems/documents';
<AiDocumentGenerationPanel type="invoice" systemId={systemId} />
```

Composes `<AiAssistantPanel>` from `@chthonic/ai` with doc-specific config.

## Quota

Shared `MaxAiPromptsPerMonth` quota (alongside AI Config Import + AI Listings).

## Related

- [`document-designer-shell.md`](document-designer-shell.md), [`four-themes.md`](four-themes.md).
- [`libraries/ai/tool-executor-pattern.md`](../ai/tool-executor-pattern.md).
