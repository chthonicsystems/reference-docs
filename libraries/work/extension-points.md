---
library: work
version: 0.3.0
related-rfcs: [0001, 0025, 0037]
last-verified: 2026-05-23
tags: [work, extension-points]
summary: Extension points — IJobStatusTransitionValidator, IJobStatusChangedHandler (auto-clock-out), IAutoCommentGenerator, IJobNumberGenerator, IOpenEntryWatchdog (forgotten-clock-out).
---

# Extension points

| Hook | Version | Use |
|---|---|---|
| `IJobStatusTransitionValidator` | v0.2.0+ | Override which status transitions are allowed (gate; pre-commit) |
| `IJobStatusChangedHandler` | v0.1.0+ | Post-commit side-effects on transition (notification dispatch, auto-clock-out, etc.) |
| `IAutoCommentGenerator` | v0.1.0+ | Customise auto-comment text |
| `IJobNumberGenerator` | v0.1.0+ | Customise job-number format (default: JOB202605220001) |
| `IOpenEntryWatchdog` (in `@chthonic/notifications` v0.2.0+) | — | Sub-daily scan to nag about forgotten-open entries (e.g. labour clock-ins > 8h). See [`@chthonic/notifications` open-entry-watchdog.md](../notifications/open-entry-watchdog.md). |

## IJobStatusChangedHandler vs IJobStatusTransitionValidator

The two hooks address different concerns:

- **`IJobStatusTransitionValidator`** is a *gate* — `Task<bool>
  CanTransitionAsync(...)` returning yes/no whether a transition is
  permitted. Fires BEFORE the transition commits. Use this when a
  rule needs to block a transition entirely (e.g. "can't move to QC
  pending without at least one kind=qc view configured").
- **`IJobStatusChangedHandler`** is a *side-effect* — fires AFTER
  the transition commits. Use this for post-commit dispatch
  (notification publish, auto-clock-out, audit-log enrichment).

Auto-clock-out (RFC 0025 / F4) is wired via the EXISTING v0.1.0
`IJobStatusChangedHandler` because it's a side-effect of the
transition, not a gate over it. Conflating the two would force the
gate to return `true` unconditionally — a category mistake. See
[RFC 0025 § 10 Alternative 4](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0025-labour-clocking.md#alternative-4-wrong-hook-for-auto-clock-out--ijobstatustransitionvalidator).

TT's `TTLabourAutoClockOutHandler` (PR 02) is a worked example —
fires on `→ Completed` and `→ PendingQcSignoff`, closes any open
`LabourEntry` rows on the job, writes a system-actor audit row.

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

- [`auto-comments.md`](auto-comments.md), [`status-transitions.md`](status-transitions.md), [`labour-clocking.md`](labour-clocking.md), [`qc-signoff.md`](qc-signoff.md).
