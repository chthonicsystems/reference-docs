---
library: work
version: 0.1.0
related-rfcs: [0001]
last-verified: 2026-05-22
tags: [work, architecture]
summary: Work internals — Job spine, mechanic assignment, auto-comment generator.
---

# Architecture

```
src/Chthonic.Work/
├── Domain/
│   ├── Job.cs
│   ├── JobMechanic.cs
│   ├── JobComment.cs
│   ├── JobApproval.cs
│   └── JobStatus.cs
├── Configuration/             # EF configs
├── Services/
│   ├── IJobService.cs / JobService.cs
│   ├── IJobMechanicService.cs / JobMechanicService.cs
│   ├── IJobApprovalService.cs / JobApprovalService.cs
│   ├── IAutoCommentGenerator.cs / AutoCommentGenerator.cs
│   └── IJobStatusTransitionValidator.cs
├── Endpoints/                 # sister-product ready
├── Migrations/
└── ServiceCollectionExtensions.cs
```

## Job statuses

```mermaid
graph LR
    IP[InProgress] --> C[Completed]
    C --> CL[Closed]
    IP --> IP_back[InProgress<br/>(revert from Completed)]
    C --> IP_back
```

Statuses: `InProgress`, `Completed`, `Closed`. Each transition emits an auto-comment + audit row.

## Auto-comment generator

Per state transition, emits a `JobComment` with `is_system=true`:

```
Status changed from InProgress to Completed by Sarah Johnson at 2026-05-22 15:30
```

Localised via `@chthonic/locale` formatters. Persists via `JobService` (same scope as the status-change request).

## Status transition validator

```csharp
public interface IJobStatusTransitionValidator
{
    bool IsValidTransition(JobStatus from, JobStatus to);
    string? GetValidationError(JobStatus from, JobStatus to);
}
```

Default impl allows all the common transitions. Consumer can override for product-specific rules.

## Tests

`JobStatusTransitionsTests` validates the matrix. `JobServiceTests` covers CRUD + auto-comment integration.

## Related

- [`job-spine.md`](job-spine.md), [`auto-comments.md`](auto-comments.md), [`status-transitions.md`](status-transitions.md).
