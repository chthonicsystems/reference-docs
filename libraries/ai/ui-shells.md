---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, ui, shells]
summary: AI UI shells — AiPill, AiSectionBanner, AiChat, AiVersionCarousel, AiArtifactEditor, AiAssistantPanel.
---

# AI UI shells

Per the platform's Option C pattern — feature shells live in their feature library. The AI library hosts the AI-generic shells that any AI feature reuses.

## Shells

| Shell | Use |
|---|---|
| `<AiPill>` | Small `✨ AI` badge for AI-touched fields |
| `<AiSectionBanner>` | Banner: AI activity / AI skipped this section / AI in progress |
| `<AiChat>` | Chat history + prompt input (reusable; supports refinement chains) |
| `<AiVersionCarousel>` | Draft + saved-versions strip (artifact-keyed) |
| `<AiArtifactEditor>` | Monaco + preview modal (split-pane, IsolatedTemplatePreview) |
| `<AiAssistantPanel>` | Composes the above into a unified panel |
| `useAiSuggestions()` | Hook for AI-suggestion state |

## `<AiAssistantPanel>` composition

```tsx
<AiAssistantPanel
  systemId={systemId}
  type="config-import"
  onGenerate={(prompt) => api.post('/api/systems/my-system/ai-config/generate', { prompt })}
  onPolling={() => api.get('/api/systems/my-system/ai-config/status')}
>
  <AiChat />
  <AiVersionCarousel onSelect={...} onSave={...} />
</AiAssistantPanel>
```

## Event-driven polling

Generations are async. The panel polls `/status` every 2s while `Pending` / `Processing`. `AiChat` exposes a `startPolling` imperative handle so modal-triggered generations can re-attach the poll loop.

## Bootstrap

```tsx
import { setAiHttp } from '@chthonicsystems/ai';
setAiHttp(httpService);
```

## Related

- [`architecture.md`](architecture.md), [`tool-executor-pattern.md`](tool-executor-pattern.md).
- Consumer-side use: [`libraries/listings/ai-generation.md`](../listings/ai-generation.md), [`libraries/documents/ai-generation.md`](../documents/ai-generation.md).
