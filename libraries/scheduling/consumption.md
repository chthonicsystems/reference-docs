---
library: scheduling
version: 0.1.0
last-verified: 2026-06-06
tags: [consumption, integration, torquetech]
summary: How to consume @chthonic/scheduling — DI registration, IDbContextProvider bridge, route-group tier gate, custom IScheduleSlotEventBus impl, frontend page composition. TorqueTech worked example throughout.
---

# Consumption

## Backend (.NET)

### 1. NuGet reference

```xml
<PackageReference Include="Chthonic.Scheduling" Version="0.1.0" />
```

### 2. DI registration

```csharp
// Program.cs
builder.Services.AddChthonicScheduling();

// Required: IDbContextProvider bridge to your DbContext.
builder.Services.AddScoped<Chthonic.Scheduling.Extensions.IDbContextProvider,
    MyAppSchedulingDbContextProvider>();

// Optional: replace default IScheduleSlotEventBus with your own
// (e.g. for FCM/APNS push on slot reassignment).
{
    var def = builder.Services.FirstOrDefault(d =>
        d.ServiceType == typeof(IScheduleSlotEventBus));
    if (def is not null) builder.Services.Remove(def);
    builder.Services.AddScoped<IScheduleSlotEventBus, MyAppScheduleSlotEventBus>();
}
```

The `MyAppSchedulingDbContextProvider` is a tiny adapter:

```csharp
public class MyAppSchedulingDbContextProvider : IDbContextProvider
{
    private readonly MyAppDbContext _db;
    public MyAppSchedulingDbContextProvider(MyAppDbContext db) => _db = db;
    public DbContext GetContext() => _db;
}
```

### 3. Apply EF configurations

```csharp
// MyAppDbContext.cs in OnModelCreating
modelBuilder.ApplyConfigurationsFromAssembly(
    typeof(Chthonic.Scheduling.SchedulingModuleMarker).Assembly);
```

### 4. Migration

The lib's `0001_Initial` creates `resource` + `schedule_slot` tables + 2 MySQL triggers. Greenfield consumers can let the migration run normally. If you need to control timing (e.g. backfilling existing data — the canonical TT pattern below), wrap in your own migration.

### 5. Mount endpoints (with optional tier gate)

```csharp
// Lib endpoints unconditional:
app.MapChthonicSchedulingEndpoints();

// OR — wrap in your own RequireFeature MapGroup for tier gating
// (TorqueTech pattern; lib stays tier-agnostic per RFC 0029 § 12 Amendment 1 12i):
app.MapGroup("")
   .RequireAuthorization()
   .AddEndpointFilter(new MyRequireFeatureFilter("MyDispatchBoardKey"))
   .MapChthonicSchedulingEndpoints();
```

## TorqueTech worked example

TT consumes the lib for Premium-tier dispatch-board, replacing the legacy `Job.ScheduledDate` column.

### Backend wiring

```csharp
// api/Program.cs
builder.Services.AddChthonicScheduling();
builder.Services.AddScoped<Chthonic.Scheduling.Extensions.IDbContextProvider,
    TorqueTech.Api.Features.Dispatch.TTSchedulingDbContextProvider>();

// Replace default no-op event bus with TT's mobile-push impl.
{
    var defaultBus = builder.Services.FirstOrDefault(d =>
        d.ServiceType == typeof(Chthonic.Scheduling.Extensions.IScheduleSlotEventBus));
    if (defaultBus is not null) builder.Services.Remove(defaultBus);
    builder.Services.AddScoped<Chthonic.Scheduling.Extensions.IScheduleSlotEventBus,
        TorqueTech.Api.Features.Dispatch.TTScheduleSlotEventBus>();
}

// Mount endpoints behind the JobsDispatchBoard tier gate.
app.MapDispatchBoardEndpoints();  // calls MapChthonicSchedulingEndpoints inside
```

### Migration choreography (the BREAKING bit)

PR 08 ships a combined backfill migration replacing `Job.ScheduledDate` with `ScheduleSlot` rows. The choreography:

```csharp
// Step 1: Register lib-side empty placeholders.
INSERT IGNORE INTO __EFMigrationsHistory VALUES
    ('20260606180000_ChthonicWork_0006_DropScheduledDate', '9.0.10'),
    ('20260606190000_ChthonicScheduling_0001_Initial', '9.0.10');

// Step 2: Apply scheduling lib's actual schema (CREATE TABLE + triggers).
// (raw SQL; idempotent via CREATE TABLE IF NOT EXISTS + DROP TRIGGER IF EXISTS)

// Step 3: Backfill from existing Job.scheduled_date.
SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME='job' AND COLUMN_NAME='scheduled_date');

// Synthesise Bay 1 (default) per system with non-null scheduled_date jobs.
INSERT INTO resource ...
SELECT DISTINCT j.system_id, 'Bay 1 (default)', 'Bay', ...
FROM job j WHERE j.scheduled_date IS NOT NULL
ON DUPLICATE KEY UPDATE name = name;

// Backfill ScheduleSlots with bypass flag set so trigger doesn't fire.
SET @sx_bypass_overlap_check = 1;
INSERT INTO schedule_slot
SELECT r.resource_id, j.system_id, j.job_id, NULL,
       TIMESTAMP(j.scheduled_date,
                SEC_TO_TIME(8*3600 + (ROW_NUMBER() OVER (PARTITION BY j.system_id, j.scheduled_date ORDER BY j.job_id) - 1) * 7200)),
       ...
FROM job j INNER JOIN resource r ON r.system_id = j.system_id AND r.name = 'Bay 1 (default)'
WHERE j.scheduled_date IS NOT NULL;
SET @sx_bypass_overlap_check = NULL;

// Step 4: LAST — drop the legacy column.
ALTER TABLE job DROP COLUMN scheduled_date;
```

**Critical: column-drop is the LAST step.** Partial-failure mid-migration leaves the column intact and recoverable. Per RFC 0029 § 12 Amendment 1 12e.

### TT-side composite endpoint

The lib's CRUD endpoints are vertical-agnostic. TT adds a composite that JOINs Job + Asset + Customer for picker preview:

```csharp
// api/Features/Dispatch/DispatchBoardEndpoints.cs
app.MapGet("/api/dispatch-board", async (
    ClaimsPrincipal user, DateTime from, DateTime to,
    TorqueTechDbContext db, CancellationToken ct) =>
{
    var systemId = user.GetSystemId();
    var resources = await db.Set<Resource>()
        .Where(r => r.SystemId == systemId && r.IsActive)
        .OrderBy(r => r.DisplayOrder).ThenBy(r => r.Name).ToListAsync(ct);
    var slots = await db.Set<ScheduleSlot>()
        .Where(s => s.SystemId == systemId && s.StartAt < to && s.EndAt > from)
        .ToListAsync(ct);
    // Hydrate Job preview in 2nd pass for picker (Job # · vehicle reg · customer)
    // ...
    return Results.Ok(new { Resources = resources, Slots = enrichedSlots });
});
```

## Frontend (TypeScript / React)

### 1. npm install

```bash
npm install @chthonicsystems/scheduling@0.1.0 @dnd-kit/core @dnd-kit/utilities
```

### 2. Adapter wire-up at app startup

```tsx
// index.tsx
import { setSchedulingHttp } from '@chthonicsystems/scheduling';
import { httpService } from './services/httpService';

const schedulingHttpAdapter = {
  get: <T,>(url: string) => httpService.get(url) as Promise<T>,
  post: <T,>(url: string, body: unknown) => httpService.post(url, body) as Promise<T>,
  put: <T,>(url: string, body: unknown) => httpService.put(url, body) as Promise<T>,
  delete: (url: string) => httpService.delete(url).then(() => undefined),
};
setSchedulingHttp(schedulingHttpAdapter);
```

### 3. Compose the dispatch board page

```tsx
// pages/DispatchBoard.tsx
import { DispatchBoardLayout, useReassignSlot } from '@chthonicsystems/scheduling';

export default function DispatchBoard() {
  const { user } = useAuth() ?? {};
  const reassign = useReassignSlot();

  return (
    <DispatchBoardLayout
      systemId={user.system.systemId}
      from={fromIso}
      to={toIso}
      renderSlotPreview={(slot) => <span>Job #{slot.jobId}</span>}
      renderLaneHeader={(resource) => (
        <span>{resource.name} <small>{resource.resourceType}</small></span>
      )}
      onSlotDragEnd={(payload) => {
        reassign({
          scheduleSlotId: payload.scheduleSlotId,
          resourceId: payload.newResourceId,
          startAt: payload.newStartAt,
          endAt: payload.newEndAt,
        });
      }}
    />
  );
}
```

### 4. Mobile read-only view

```tsx
// pages/MySchedule.tsx — mobile only, no drag-drop
import { useScheduleSlots } from '@chthonicsystems/scheduling';

const { data: slots } = useScheduleSlots(systemId, todayIso, tomorrowIso);
// render IonList of slots
```

## Cross-references

- [Architecture](architecture.md)
- [Extension points](extension-points.md)
- [`@chthonic/booking` consumption (customer-side counterpart)](../booking/consumption.md)
- TT integration PR: [chthonicsystems/torquetech#306](https://github.com/chthonicsystems/torquetech/pull/306)
