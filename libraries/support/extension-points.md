---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, extension-points]
summary: Extension points — IIssueTrackerProvider for new providers + CTI seeding.
---

# Extension points

| Hook | Use |
|---|---|
| `IIssueTrackerProvider` | Add Linear / Jira / Zendesk / etc. |
| CTI seed | Tenants/sysadmins populate `cti_routing` |
| Two-package shape | Each provider ships as `Chthonic.Support.<Provider>` |

## Adding a provider

```csharp
public class LinearIssueTrackerProvider : IIssueTrackerProvider
{
    public string Name => "linear";
    public Task<string> CreateIssueAsync(SupportTicket ticket, CtiRouting cti) { /* Linear GraphQL */ }
    public Task UpdateIssueAsync(string externalId, SupportTicket ticket) { /* */ }
    public Task<string?> GetStatusAsync(string externalId) { /* */ }
}
```

Phase-2 sister packages: `Chthonic.Support.Linear`, `Chthonic.Support.Jira`, `Chthonic.Support.Zendesk`. Same pattern as payments + billing.

## Related

- [`issue-tracker-abstraction.md`](issue-tracker-abstraction.md), [`github-sync.md`](github-sync.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 2 (two-package shape).
