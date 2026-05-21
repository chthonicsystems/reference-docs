---
library: audit
version: 0.1.4
related-rfcs: [0006]
last-verified: 2026-05-22
tags: [audit, consumption]
summary: Code-level integration walkthrough for @chthonic/audit.
---

# Consuming `@chthonic/audit`

## 1. Add package reference

```xml
<PackageReference Include="Chthonic.Audit" Version="0.1.4" />
```

## 2. Register RabbitMQ adapter

```csharp
public class RabbitMqConnectionAdapter : IRabbitMqConnection, IDisposable
{
    private readonly IConnection _conn;
    public RabbitMqConnectionAdapter(IConfiguration config)
    {
        var factory = new ConnectionFactory { Uri = new Uri(config["RABBITMQ_URL"]!) };
        _conn = factory.CreateConnection("chthonic-audit");
    }
    public IConnection GetConnection() => _conn;
    public void Dispose() => _conn?.Dispose();
}

builder.Services.AddSingleton<IRabbitMqConnection, RabbitMqConnectionAdapter>();
```

## 3. Register Audit DI + interceptor

```csharp
using Chthonic.Audit;

builder.Services.AddChthonicAudit(builder.Configuration);

builder.Services.AddDbContext<TorqueTechDbContext>((sp, opts) => {
    opts.UseMySql(connStr, ...)
        .AddInterceptors(sp.GetRequiredService<AuditSaveChangesInterceptor>());
});

var app = builder.Build();
app.MapAuditEndpoints();
```

## 4. Annotate domain entities

```csharp
[AuditCategory("Work")]
public class Job { ... }

[AuditCategory("Work")]
[AuditParent(typeof(Job), nameof(JobId))]
public class JobMechanic
{
    public int JobMechanicId { get; set; }
    public int JobId { get; set; }
    public int UserId { get; set; }
    // ...
}
```

A change to `JobMechanic` rolls up an audit row with `entity_type='JobMechanic'` AND `parent_type='Job'`, `parent_id=JobId`. The audit-log viewer can show the parent's history threadwise.

## 5. Cross-library `[AuditParent]` (string variant)

```csharp
// In @chthonic/parties:
[AuditCategory("Parties")]
[AuditParent("Vehicle", nameof(VehicleId))]    // string; doesn't reference @chthonic/assets
public class CustomerVehicle { ... }
```

Parties can roll up to a parent type (`"Vehicle"`) it doesn't compile-time-reference. See [`auditparent-attribute.md`](auditparent-attribute.md).

## 6. Manual write

```csharp
public class JobService(IAuditLogger audit, ICurrentUser user)
{
    public async Task CompleteAsync(Job job)
    {
        var oldStatus = job.Status;
        job.Status = JobStatus.Completed;
        await _db.SaveChangesAsync();

        await audit.LogAsync(new AuditEntry
        {
            SystemId = job.SystemId,
            UserId = user.Id,
            Category = AuditCategory.Work,
            Action = "job.completed",
            EntityType = "Job",
            EntityId = job.JobId,
            Changes = new() { ["status"] = new[] { oldStatus.ToString(), "Completed" } },
        });
    }
}
```

Most consumers rely on the interceptor for free; manual `LogAsync` is for cross-cutting events not tied to a single entity row (login, export started, etc.).

## 7. Read audit logs

```csharp
public class AuditViewerEndpoint(IAuditQueryService q)
{
    [HttpGet("/api/audit-logs")]
    public Task<PagedResult<AuditLog>> List([FromQuery] AuditLogFilter filter)
        => q.SearchAsync(filter);
}
```

The library's `MapAuditEndpoints` ships this for you. Consumer adds RBAC (`page:audit-logs` permission).

## 8. Verification

- [ ] `audit_log` rows written on every `[AuditCategory]`-tagged entity change.
- [ ] `[AuditParent]` rollup populates `parent_type` + `parent_id`.
- [ ] RabbitMQ DLQ is empty in steady state.
- [ ] `AuditRetentionService` background job cleans rows older than retention.
- [ ] `/api/audit-logs` viewer returns paginated history.

## Related

- [`index.md`](index.md), [`architecture.md`](architecture.md), [`extension-points.md`](extension-points.md).
- [`auditparent-attribute.md`](auditparent-attribute.md), [`rabbitmq-pipeline.md`](rabbitmq-pipeline.md).
