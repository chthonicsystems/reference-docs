---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, tool-executor, extension-pattern]
summary: IToolExecutor — per-feature tool definition + execution. Each AI feature implements one.
---

# IToolExecutor pattern

Each AI feature (Config Import, Listing Templates, Document Designer per type) implements `IToolExecutor`. Defines the tools the AI can call + handles each tool's invocation.

## Interface

```csharp
public interface IToolExecutor
{
    string Type { get; }                                   // 'config-import', 'listing-template', ...
    List<SystemContentBlock> GetSystemPrompt();
    List<ToolDefinition> GetTools();
    Task<ToolResult> RunToolAsync(string toolName, JsonElement input, CancellationToken ct);
}
```

## Example: AI Config Import

10 tools (login, fetch_url, update_profile, update_localization, ...). Each tool is a structured action — fetching a web page, updating a config section.

```csharp
public class ConfigImportToolExecutor : IToolExecutor
{
    public string Type => "config-import";

    public List<ToolDefinition> GetTools() => new()
    {
        new() { Name = "fetch_url", InputSchema = JsonSchema(typeof(FetchUrlInput)), Description = "Fetch a web page or PDF." },
        new() { Name = "update_profile", InputSchema = JsonSchema(typeof(UpdateProfileInput)), Description = "Update business profile fields." },
        // ... 8 more
    };

    public async Task<ToolResult> RunToolAsync(string toolName, JsonElement input, CancellationToken ct)
    {
        return toolName switch
        {
            "fetch_url" => await ExecuteFetchUrlAsync(input.Deserialize<FetchUrlInput>()!, ct),
            "update_profile" => await ExecuteUpdateProfileAsync(input.Deserialize<UpdateProfileInput>()!, ct),
            // ...
            _ => ToolResult.Error($"Unknown tool: {toolName}")
        };
    }
}
```

## Per-feature scope

| Feature | Executor | Tools |
|---|---|---|
| AI Config Import | `ConfigImportToolExecutor` | login, fetch_url, update_profile, update_localization, update_tax, update_payment_terms, update_working_hours, update_terminology, create_service, suggest_integration |
| AI Listing Templates | `ListingTemplateToolExecutor` | render_html, edit_css, suggest_color_scheme |
| AI Document Designer (per type) | `Ai{Type}TemplateToolExecutor` × 4 | type-specific tools |

## Adding a new feature

1. Implement `IToolExecutor`.
2. Register in DI: `services.AddScoped<IToolExecutor, MyExecutor>()`.
3. Update `AiGenerationConsumer.ResolveExecutor()` switch with the new `Type`.
4. Add type-specific endpoints (kick off generation; check status).

## Related

- [`extension-points.md`](extension-points.md), [`ai-tool-loop.md`](ai-tool-loop.md).
