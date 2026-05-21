---
library: audit
package-nuget: Chthonic.Audit
package-npm: '@chthonicsystems/audit'
version: 0.1.4
related-rfcs: [0006]
related-libs: [tenant]
last-verified: 2026-05-22
tags: [core-domain, audit, observability, rabbitmq]
summary: Append-only audit log + IAuditLogger contract + RabbitMQ async write pipeline.
---

# `@chthonicsystems/audit` / `Chthonic.Audit`

Every state change in a Chthonic product flows through this library: who, what, when, on what entity, what changed. Append-only.

## Purpose

- One canonical audit log table (`audit_log`) per consumer.
- `IAuditLogger.LogAsync(...)` writes via RabbitMQ + an async consumer (decouples request latency from audit write throughput).
- `AuditSaveChangesInterceptor` auto-detects EF entity changes via `[AuditParent]` / `[AuditCategory]` attributes.
- `AuditQueryService` for the audit-log viewer page.
- `AuditRetentionService` periodic cleanup (configurable retention).

## Public surface

### .NET

| Type | File | Role |
|---|---|---|
| `IAuditLogger` / `AuditLogger` | `src/Chthonic.Audit/Services/AuditLogger.cs` | `LogAsync(AuditEntry)` — primary write API |
| `AuditSaveChangesInterceptor` | `src/Chthonic.Audit/AuditSaveChangesInterceptor.cs` | EF interceptor; auto-emits audit on entity changes via attributes |
| `[AuditParent]` / `[AuditCategory]` attributes | `src/Chthonic.Audit/Domain/AuditAttributes.cs` | Annotate entity classes/properties to enroll |
| `IAuditQueryService` | `src/Chthonic.Audit/Services/IAuditQueryService.cs` | Read API for UI |
| `IAuditRetentionService` | `src/Chthonic.Audit/Services/IAuditRetentionService.cs` | Periodic cleanup |
| `AuditLog` entity | `src/Chthonic.Audit/Domain/AuditLog.cs` | The canonical row |
| `AuditEntry` DTO | `src/Chthonic.Audit/Domain/AuditEntry.cs` | Input shape for `LogAsync` |
| `AuditCategory` enum | `src/Chthonic.Audit/Domain/AuditCategory.cs` | `Tenant`, `Identity`, `Parties`, `Work`, `Billing`, ... |
| `IRabbitMqConnection` (port) | `src/Chthonic.Audit/IRabbitMqConnection.cs` | Consumer registers RabbitMQ adapter |
| `MapAuditEndpoints` | (file) | `/api/audit-logs/*` (read-only viewer endpoints) |
| `services.AddChthonicAudit(config)` | `src/Chthonic.Audit/ServiceCollectionExtensions.cs` | DI entry point |

### npm

`@chthonicsystems/audit` is reserved for future audit-viewer UI shells; v0.1.4 ships an empty package (consumers render audit-log viewers from their own components). The audit-log read endpoints (`/api/audit-logs/*`) feed any UI directly.

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | `system_id` scoping; consumed indirectly via `AuditEntry.SystemId` |
| `RabbitMQ.Client` (consumer-supplied via port) | Async write pipeline |
| `Microsoft.EntityFrameworkCore` | EF interceptor + audit_log table |

## Schema

```
audit_log
  audit_log_id    bigint PK AUTO_INCREMENT
  system_id       int
  user_id         int?     (nullable for system-emitted entries)
  category        varchar(50)
  action          varchar(100)   ("vehicle.updated", "user.login", ...)
  entity_type     varchar(100)   ("Job", "Customer", ...)
  entity_id       int?
  parent_type     varchar(100)?  ("Customer" for a CustomerVehicle change → rolls up)
  parent_id       int?
  changes         json           ({ "field": ["before", "after"], ... })
  metadata        json           extra context (ip, user-agent, etc.)
  created_at      datetime

  index ix_audit_system_created (system_id, created_at)
  index ix_audit_entity (entity_type, entity_id)
```

## Pipeline

```mermaid
graph LR
    A["Service code:<br/>_audit.LogAsync(entry)"]
    R[RabbitMQ exchange<br/>'audit-log']
    C[AuditLogConsumer<br/>BackgroundService]
    DB[audit_log INSERT]

    EF["EF SaveChanges"]
    I[AuditSaveChangesInterceptor]
    I -->|auto-emit per [AuditParent]| A

    A --> R --> C --> DB
```

Async + decoupled — request latency never blocked on audit write.

## Extension points

| Hook | Use |
|---|---|
| `[AuditParent("Customer", nameof(CustomerId))]` on EF entity | Auto-roll-up child changes to parent entity |
| `[AuditCategory("Work")]` on EF entity | Tag audit category |
| `IRabbitMqConnection` (port) | Consumer registers RabbitMQ adapter (default impl uses `RabbitMQ.Client`) |
| `services.AddChthonicAudit(opts => opts.RetentionDays = 365)` | Per-product retention |

## Consuming this library

```csharp
builder.Services.AddSingleton<IRabbitMqConnection, RabbitMqConnectionAdapter>();
builder.Services.AddChthonicAudit(builder.Configuration);

// Auto-interceptor wires into EF
builder.Services.AddDbContext<TorqueTechDbContext>((sp, opts) => {
    opts.UseMySql(...)
        .AddInterceptors(sp.GetRequiredService<AuditSaveChangesInterceptor>());
});

app.MapAuditEndpoints();
```

```csharp
// Manual audit write
await _audit.LogAsync(new AuditEntry
{
    SystemId = systemId,
    UserId = currentUser.Id,
    Category = AuditCategory.Work,
    Action = "job.completed",
    EntityType = "Job",
    EntityId = jobId,
    Changes = new() { ["status"] = new[] { "InProgress", "Completed" } },
});
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`auditparent-attribute.md`](auditparent-attribute.md), [`rabbitmq-pipeline.md`](rabbitmq-pipeline.md), [`cross-library-writes.md`](cross-library-writes.md).
- [RFC 0006](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0006-audit-logging.md).
