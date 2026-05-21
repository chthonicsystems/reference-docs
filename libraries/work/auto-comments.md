---
library: work
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [work, auto-comments]
summary: AutoCommentGenerator — system-emitted comments on every status transition.
---

# Auto comments

Every Job state change emits a `JobComment` with `is_system=true`. Powers the audit trail in the UI.

## Output examples

```
Job moved from In Progress → Completed by Sarah Johnson at 22/05/2026 3:30 pm
Mechanic Phil added to job by Sarah Johnson
Mechanic Anna removed from job by Sarah Johnson
Approval requested by Sarah Johnson
Approval granted by Mike (admin)
```

Localised: dates + times respect the tenant's `@chthonic/locale` config.

## Implementation

```csharp
public class AutoCommentGenerator : IAutoCommentGenerator
{
    public string OnStatusChange(JobStatus from, JobStatus to, string actorName, DateTime at)
        => $"Job moved from {from} to {to} by {actorName} at " +
           $"{FormatHelper.FormatDateTime(at, _locale.DateFormat, _locale.Timezone)}";

    public string OnMechanicAdded(string mechanicName, string actorName) =>
        $"Mechanic {mechanicName} added to job by {actorName}";

    // ... etc
}
```

## Persistence

`JobService.UpdateStatusAsync(...)` calls the generator + persists the comment in the same transaction. Failures roll back the status change too.

## Suppressing

Bulk imports (e.g. data import migrations) skip auto-comments via:

```csharp
using (_jobs.SuppressAutoComments())
{
    await _jobs.UpdateStatusAsync(jobId, JobStatus.Completed);
}
```

Comments don't fire; status still updates.

## Customising

Override `IAutoCommentGenerator`. See [`extension-points.md`](extension-points.md).

## Related

- [`status-transitions.md`](status-transitions.md), [`job-spine.md`](job-spine.md).
