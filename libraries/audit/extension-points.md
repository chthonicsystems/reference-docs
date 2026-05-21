---
library: audit
version: 0.1.4
related-rfcs: [0006]
last-verified: 2026-05-22
tags: [audit, extension-points]
summary: Extension points — RabbitMQ adapter, AuditCategory enum, retention config.
---

# Extension points

| Hook | Use |
|---|---|
| `IRabbitMqConnection` (port) | Consumer-supplied RabbitMQ connection. Default: nothing — consumer registers an adapter wrapping `RabbitMQ.Client` |
| `[AuditCategory("X")]` on EF entity | Tag with a category for filtering / dashboards |
| `[AuditParent(parentType, fkProperty)]` on EF entity | Roll up to a parent type for thread-wise viewing |
| `services.AddChthonicAudit(opts => opts.RetentionDays = 730)` | Per-product retention |
| Custom `IAuditQueryService` | Override read-API for specialised filtering |

## Adding an audit category

`AuditCategory` is a `string` (despite the enum class style). Adding `"Marketplace"`:

1. Add `public const string Marketplace = "Marketplace";` to `AuditCategory.cs` (mostly aesthetic; the runtime value is the string).
2. Annotate relevant entities with `[AuditCategory("Marketplace")]`.
3. The audit viewer's filter dropdown reads distinct categories from the table; new category appears automatically.

## Configuring retention

```csharp
builder.Services.AddChthonicAudit(opts =>
{
    opts.RetentionDays = 730;        // 2 years
    opts.BatchSize = 50;             // consumer batch size
    opts.RabbitMqExchange = "audit-log";
    opts.RabbitMqQueue = "audit-log";
    opts.DeadLetterQueue = "audit-log-dlq";
});
```

## Custom query service

```csharp
public class MyAuditQueryService : IAuditQueryService { ... }
builder.Services.AddScoped<IAuditQueryService, MyAuditQueryService>();
```

Replaces the default. Useful for products with audit-specific UI requirements (e.g. PetCare exposing an "audit by pet" filter).

## Skipping auto-emit per save

For services that handle audit themselves:

```csharp
using (_db.SuppressAuditInterceptor())   // extension method
{
    _db.Jobs.Update(job);
    await _db.SaveChangesAsync();
}
```

(The library exposes `IDbContext.SuppressAuditInterceptor()` as an `IDisposable` scope.)

## Custom retention policy

Override `IAuditRetentionService`:

```csharp
public class TenantTierAwareRetention : IAuditRetentionService
{
    public async Task RunAsync()
    {
        // Premium tenants keep 730 days; Standard 365; Free 90
        foreach (var (tier, days) in new[] { ("Premium", 730), ("Standard", 365), ("Free", 90) })
            await DeleteOlderThanAsync(tier, days);
    }
}

builder.Services.AddScoped<IAuditRetentionService, TenantTierAwareRetention>();
```

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`consumption.md`](consumption.md).
- [`auditparent-attribute.md`](auditparent-attribute.md), [`rabbitmq-pipeline.md`](rabbitmq-pipeline.md), [`cross-library-writes.md`](cross-library-writes.md).
