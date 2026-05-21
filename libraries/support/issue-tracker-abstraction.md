---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, issue-tracker]
summary: IIssueTrackerProvider interface — abstracts external trackers (GitHub Phase-1; Linear/Jira/Zendesk Phase-2).
---

# IIssueTrackerProvider abstraction

```csharp
public interface IIssueTrackerProvider
{
    string Name { get; }   // 'github', 'linear', 'jira', 'zendesk'

    Task<string> CreateIssueAsync(SupportTicket ticket, CtiRouting cti);
    Task UpdateIssueAsync(string externalId, SupportTicket ticket);
    Task<string?> GetStatusAsync(string externalId);
    Task SyncCommentsAsync(string externalId, IEnumerable<TicketComment> comments);
}
```

## Two-package shape

```
Chthonic.Support              # interface + ticket service
Chthonic.Support.GitHub       # GitHubIssueTrackerProvider
Chthonic.Support.Linear       # (Phase-2)
Chthonic.Support.Jira         # (Phase-2)
Chthonic.Support.Zendesk      # (Phase-2)
```

## Multi-provider in one tenant

Different CTIs route to different providers. A "Bug / API / login fails" goes to GitHub; "Bug / Mobile / app crashes" goes to Linear. The library reads `cti_routing.external_provider` per match + dispatches to the correct provider.

## Failure handling

External-tracker failures are logged but DON'T block ticket creation. The ticket exists locally; sync retries on a periodic background job (deferred to v0.2.0).

## Related

- [`github-sync.md`](github-sync.md), [`extension-points.md`](extension-points.md).
- [`platform/extension-patterns.md`](../../platform/extension-patterns.md) § 2 (two-package shape).
