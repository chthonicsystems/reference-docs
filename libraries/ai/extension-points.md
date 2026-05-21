---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, extension-points]
summary: Extension points — IToolExecutor, model override, max-iterations override.
---

# Extension points

| Hook | Use |
|---|---|
| `IToolExecutor` | Implement per AI feature (config-import, listing-template, jobcard, etc.) |
| `AiGenerationConsumer.ResolveExecutor()` | Register new AI type → executor mapping |
| `AWS:Bedrock:ModelId` | Override model |
| `services.AddChthonicAi(opts.MaxToolLoopIterations = 30)` | Override default 20 |

## Adding a new AI type

```
1. Implement IToolExecutor with type-specific tools.
2. Register: services.AddScoped<IToolExecutor, MyToolExecutor>();
3. Add a case to AiGenerationConsumer.ResolveExecutor():
     return type switch {
         "my-feature" => sp.GetRequiredService<MyToolExecutor>(),
         ...
     };
4. Add type-specific endpoints (POST /api/.../ai-myfeature/generate, etc.).
5. Library logging + queue + tool-loop work automatically.
```

## Related

- [`tool-executor-pattern.md`](tool-executor-pattern.md), [`ai-tool-loop.md`](ai-tool-loop.md).
