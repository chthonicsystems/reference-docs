---
library: ai
package-nuget: Chthonic.AI
package-npm: '@chthonicsystems/ai'
version: 0.1.0
related-rfcs: [0013]
related-libs: [tenant, identity, audit]
last-verified: 2026-05-22
tags: [feature, ai, bedrock, tool-use]
summary: Bedrock + AiToolLoop + IToolExecutor pattern + ECDSA keypair auth + AI UI shells.
---

# `@chthonicsystems/ai` / `Chthonic.AI`

Shared AI infrastructure for every AI-powered feature on the platform: AI Config Import, AI Listing Templates, AI Document Designer (per-doc-type). Bedrock Converse API + tool-use loop + per-feature `IToolExecutor` pattern + ECDSA keypair auth + `AiGeneration` entity + RabbitMQ consumer + AI UI shells.

## Purpose

- Single Bedrock client + tool loop reused across all AI features.
- Per-feature `IToolExecutor` registers tools the AI can call.
- All AI work goes through `POST /generate` → RabbitMQ → `AiGenerationConsumer` → executor.
- ECDSA keypair auth for the tool-loop's HTTP callbacks.
- AI session logging to CloudWatch.
- React UI shells (AiPill, AiChat, AiVersionCarousel, AiArtifactEditor) live here so feature libraries reuse.

## Public surface

### .NET

| Type | Role |
|---|---|
| `IAiClient` / `BedrockAiClient` | Bedrock Converse API wrapper |
| `IAiKeypairProvider` / `SecretsManagerAiKeypairProvider` | ECDSA keypair from AWS Secrets Manager |
| `IAiKeyAuthHelper` / `AiKeyAuthHelper` | Keypair signing for tool-loop callbacks |
| `IAiSessionLogger` / `CloudWatchAiSessionLogger` | Log to CloudWatch |
| `IToolExecutor` | Per-feature tool execution interface |
| `AiToolLoop` | Orchestrator — drives Bedrock + tool calls (max 20 iterations) |
| `AiGeneration` entity + `AiGenerationConsumer` (BackgroundService) | Generation queue + state machine |
| `MapAiGenerationsEndpoints` | `/api/ai-generations/*` (sysadmin) |
| `services.AddChthonicAi(config)` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<AiPill>` | Small `✨ AI` badge for AI-touched fields |
| `<AiSectionBanner>` | Banner: AI activity / AI skipped this section |
| `<AiChat>` | Chat history + prompt input |
| `<AiVersionCarousel>` | Draft + saved-versions strip |
| `<AiArtifactEditor>` | Monaco + preview modal |
| `<AiAssistantPanel>` | Composes the above into a panel |
| `useAiSuggestions()` | Hook for AI-suggestion state |

## Schema

```
ai_generation
  ai_generation_id  int PK
  system_id         int
  type              varchar    'config-import', 'listing-template', 'jobcard-template', 'invoice-template', ...
  prompt            text
  status            enum 'Pending', 'Processing', 'Completed', 'Failed'
  version           int        for refinement chains
  parent_generation_id int FK?  for branching
  is_finalized      bool
  metadata          json
  created_at        datetime
  completed_at      datetime?

  index ix_ai_gen_system_type_status (system_id, type, status)

ai_prompt
  ai_prompt_id      int PK
  ai_generation_id  int FK
  text              text
  parent_prompt_id  int FK?
  tool_call_summary text?
  created_at        datetime

ai_artifact
  ai_artifact_id    int PK
  ai_prompt_id      int FK
  name              varchar    'Draft' or user-chosen version name
  s3_key            varchar?
  created_at        datetime
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id + entitlements (MaxAiPromptsPerMonth quota) |
| `@chthonic/identity` | API-key auth for tool-loop callbacks |
| `@chthonic/audit` | Audit on AI generation completion |
| `AWSSDK.BedrockRuntime` | Bedrock Converse API |
| `AWSSDK.SecretsManager` | Keypair retrieval |
| `AWSSDK.CloudWatchLogs` | Session logging |
| `RabbitMQ.Client` | Generation queue |

## Extension points

| Hook | Use |
|---|---|
| `IToolExecutor` | Implement per AI feature; register in `AiGenerationConsumer.ResolveExecutor()` |
| Adding a new AI type | Implement executor → register → add type-specific endpoints |
| Bedrock model override | Configure `AWS:Bedrock:ModelId` env var |
| Tool-loop max iterations | Default 20; override via DI options |

## Consuming this library

```csharp
using Chthonic.AI;
builder.Services.AddChthonicAi(builder.Configuration);
builder.Services.AddScoped<IToolExecutor, MyFeatureToolExecutor>();
app.MapAiGenerationsEndpoints();
```

```tsx
import { setAiHttp, AiPill, AiAssistantPanel } from '@chthonicsystems/ai';
setAiHttp(httpService);
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`bedrock-integration.md`](bedrock-integration.md), [`ai-tool-loop.md`](ai-tool-loop.md), [`tool-executor-pattern.md`](tool-executor-pattern.md), [`ecdsa-keypair-auth.md`](ecdsa-keypair-auth.md), [`ui-shells.md`](ui-shells.md).
- Library repo: [chthonicsystems/ai](https://github.com/chthonicsystems/ai).
- [RFC 0013](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0013-ai-infrastructure.md).
