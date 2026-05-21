---
library: work
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [work, extension-points]
summary: Extension points — IJobStatusTransitionValidator, IAutoCommentGenerator, IJobNumberGenerator.
---

# Extension points

| Hook | Use |
|---|---|
| `IJobStatusTransitionValidator` | Override which status transitions are allowed |
| `IAutoCommentGenerator` | Customise auto-comment text |
| `IJobNumberGenerator` | Customise job-number format (default: JOB202605220001) |

## IJobStatusTransitionValidator

Per-product status rules. Marine deck might want a `BlockedByWeather` status; PetCare might gate `Completed` until a vet sign-off.

```csharp
public class MarineDeckJobValidator : IJobStatusTransitionValidator
{
    public bool IsValidTransition(JobStatus from, JobStatus to) => (from, to) switch
    {
        (JobStatus.InProgress, JobStatus.BlockedByWeather) => true,
        (JobStatus.BlockedByWeather, JobStatus.InProgress) => true,
        // ...
        _ => DefaultRules(from, to)
    };
}
```

## IAutoCommentGenerator

Override the canonical text:

```csharp
public class MyAutoCommentGenerator : IAutoCommentGenerator
{
    public string OnStatusChange(JobStatus from, JobStatus to, string actorName)
        => $"Job moved from {from} to {to} by {actorName}";
}
```

## IJobNumberGenerator

```csharp
public interface IJobNumberGenerator
{
    Task<string> GenerateAsync(int systemId);
}
```

Default returns `JOB{yyyyMMdd}{seq:D4}`. Customise per tenant.

## Related

- [`auto-comments.md`](auto-comments.md), [`status-transitions.md`](status-transitions.md).
