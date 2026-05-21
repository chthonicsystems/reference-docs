---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, tool-loop]
summary: AiToolLoop — Bedrock Converse + tool-call cycle, max 20 iterations.
---

# AiToolLoop

Drives the AI session. Posts to Bedrock; if the response includes `tool_use`, runs the tool via the executor; appends the result to the message history; re-posts. Loops until `end_turn` or max-iterations cap.

## Algorithm

```csharp
public async Task<AiToolLoopResult> RunAsync(IToolExecutor executor, string prompt, CancellationToken ct)
{
    var messages = new List<Message> { new() { Role = "user", Text = prompt } };
    var system = executor.GetSystemPrompt();
    var tools = executor.GetTools();

    for (int i = 0; i < _opts.MaxIterations; i++)
    {
        ct.ThrowIfCancellationRequested();
        var response = await _bedrock.ConverseAsync(new() { Messages = messages, System = system, ToolConfig = tools });

        await _logger.LogTurnAsync(generation.Id, response);

        if (response.StopReason == "end_turn")
            return new() { Success = true, Messages = messages };

        if (response.StopReason == "tool_use")
        {
            foreach (var toolCall in response.ToolCalls)
            {
                var toolResult = await executor.RunToolAsync(toolCall.Name, toolCall.Input, ct);
                messages.Add(new() { Role = "user", ToolResult = (toolCall.Id, toolResult) });
            }
            continue;
        }
    }
    return new() { Success = false, Messages = messages, Error = "Max iterations exceeded" };
}
```

## Cancellation

Cancel via `cancellation_token` propagation. `POST /api/ai-generations/{id}/cancel` (sysadmin) flips the token; the next iteration's `ct.ThrowIfCancellationRequested()` aborts.

## Logging

Every turn (Bedrock request + response) → `IAiSessionLogger.LogTurnAsync` → CloudWatch log stream `generation-{id}`. Useful for debugging + auditing.

## Related

- [`tool-executor-pattern.md`](tool-executor-pattern.md), [`bedrock-integration.md`](bedrock-integration.md).
