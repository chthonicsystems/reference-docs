---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, architecture]
summary: Support internals — ticket entity, CTI routing, two-package shape (interface + GitHub impl).
---

# Architecture

```
src/Chthonic.Support/
├── Domain/SupportTicket.cs, CtiRouting.cs
├── Configuration/, Migrations/
├── Services/
│   ├── ISupportTicketService.cs / SupportTicketService.cs
│   ├── ICtiRoutingService.cs / CtiRoutingService.cs
│   └── IIssueTrackerProvider.cs (interface; impl in sister package)
├── Endpoints/
└── ServiceCollectionExtensions.cs

src/Chthonic.Support.GitHub/    (sister package)
├── GitHubIssueTrackerProvider.cs : IIssueTrackerProvider
├── GitHubOptions.cs (token, default_repo)
└── ServiceCollectionExtensions.cs
```

## State machine

```
Open → In Progress → Resolved → Closed
            ↓
         (back to Open if reopened)
```

## CTI routing

`CtiRoutingService.MatchAsync(category, type, item)` looks up the CTI row + returns the resolver group + external provider config (if any). When a ticket is created with a matching CTI, the service:

1. Sets `support_ticket.resolver_group`.
2. If `external_provider != null`, calls `IIssueTrackerProvider.CreateIssueAsync` + stores `external_issue_id`.

## Tests

`SupportTicketServiceTests`, `CtiRoutingServiceTests`, `GitHubIssueTrackerProviderTests` (HTTP mocked).

## Related

- [`ticketing.md`](ticketing.md), [`cti-routing.md`](cti-routing.md), [`issue-tracker-abstraction.md`](issue-tracker-abstraction.md), [`github-sync.md`](github-sync.md).
