---
library: listings
version: 0.1.0
related-rfcs: [0014]
related-libs: [ai]
last-verified: 2026-05-22
tags: [listings, ai, generation]
summary: AI-generated listing themes — prompt-centric session, artifact-keyed carousel, manual edit.
---

# AI generation

5th option alongside the 4 pre-built themes. Admins generate a custom theme by typing a prompt. Powered by `@chthonic/ai`.

## Session model (prompt-centric, artifact-keyed)

- Each user instruction → new `AiPrompt` (chainable via `parent_prompt_id` for refinements/branching).
- Artifacts at `s3://.../ai-artifacts/{systemId}/prompt-{promptId}/` belong to the prompt.
- `ai_artifact` rows = versions:
  - `Name = "Draft"` — single in-progress per system; advances `ai_prompt_id`.
  - `Name = "<user-chosen>"` — saved version. `/save` creates a new row pointing at Draft's current `ai_prompt_id` (no S3 copy).
- `system_listing.active_ai_artifact_id` — live version. Two write paths: `/save` + `PUT /listing` (switching between saved versions).

## Carousel selection

UI keys selection by **`artifactId`** (unique per row), NOT by `promptId` (which can be shared between Draft and one derived saved version).

## Manual edit UX

`<AiArtifactEditor>` modal (Monaco lazy-loaded, split-pane with `<IsolatedPreview>`, 500ms debounce). Save POSTs to `/edit` → creates new `AiPrompt` (`Text = "Manual edit"`) → `RenderedHtmlSecurityPolicy` runs on `index.liquid`. Manual edits don't consume the monthly AI quota (no Bedrock call) but do create an `AiPrompt` row.

## Endpoints

```
/api/systems/my-system/ai-template/draft
/api/systems/my-system/ai-template/draft/from-version
/api/systems/my-system/ai-template/draft/from-prompt
/api/systems/my-system/ai-template/generate
/api/systems/my-system/ai-template/status
/api/systems/my-system/ai-template/versions
/api/systems/my-system/ai-template/save
/api/systems/my-system/ai-template/edit
/api/systems/my-system/ai-template/cancel
/api/systems/my-system/ai-template/prompt-history
/api/systems/my-system/ai-template/prompts/{promptId}/artifacts
/api/listing-templates/ai-v{promptId}/content
/api/listing-templates/ai-v{promptId}/assets/{path}
```

## Feature flag

`ListingTemplateAI` (Standard + Premium). Quota: shared `MaxAiPromptsPerMonth` on `SystemPackage` (5 Standard, 20 Premium).

## Related

- [`four-themes.md`](four-themes.md), [`public-listing-page.md`](public-listing-page.md).
- [`libraries/ai/ui-shells.md`](../ai/ui-shells.md), [`libraries/ai/tool-executor-pattern.md`](../ai/tool-executor-pattern.md).
