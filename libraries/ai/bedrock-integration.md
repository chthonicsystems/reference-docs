---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, bedrock, claude]
summary: Bedrock Converse API integration — model selection, request shape, response parsing.
---

# Bedrock integration

`BedrockAiClient` wraps the AWS Bedrock Converse API. Default model: Claude Sonnet 4.5 (`anthropic.claude-sonnet-4-5-20250929-v1:0`).

## Converse request shape

```csharp
var response = await _bedrock.ConverseAsync(new ConverseRequest
{
    ModelId = _opts.ModelId,
    Messages = messages,
    System = systemPromptBlocks,
    ToolConfig = new() { Tools = toolDefinitions },
});
```

`messages` accumulates user / assistant / tool-result turns. `toolDefinitions` is the executor's declared tools.

## Tool-call cycle

Each Bedrock response can contain:

- `text` — assistant prose.
- `tool_use` — assistant requests to call a named tool.
- `stop_reason='end_turn'` — done.
- `stop_reason='tool_use'` — call a tool + send result back.

`AiToolLoop` handles the cycle (see [`ai-tool-loop.md`](ai-tool-loop.md)).

## Model override

```bash
AWS__Bedrock__ModelId=anthropic.claude-haiku-4-20250929-v1:0   # cheaper for simpler features
```

Per-feature model override lives in the `IToolExecutor` if needed.

## Guardrails

Bedrock guardrails (per-tenant or org-wide) optional. If a guardrail trips, the generation ends `Failed`. Suggestions written before the trip survive (intentional — partial work isn't lost).

## Related

- [`ai-tool-loop.md`](ai-tool-loop.md), [`tool-executor-pattern.md`](tool-executor-pattern.md).
