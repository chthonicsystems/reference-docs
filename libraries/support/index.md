---
library: support
package-nuget: Chthonic.Support
package-npm: '@chthonicsystems/support'
version: 0.1.0
related-rfcs: [0016]
related-libs: [tenant, identity, feedback]
last-verified: 2026-05-22
tags: [communications, ticketing, two-package, github]
summary: Support tickets + CTI routing + GitHub issue sync + IIssueTrackerProvider abstraction.
---

# `@chthonicsystems/support` / `Chthonic.Support`

Two-package shape. `Chthonic.Support` owns the ticket entity + CTI routing + abstraction. `Chthonic.Support.GitHub` (Phase-1) syncs tickets to GitHub Issues. Phase-2: Linear, Jira, Zendesk.

## Purpose

In-app support tickets. Customers + staff create tickets; CTI (Category/Type/Item) routing assigns to the right resolver group. Tickets optionally sync to an external issue tracker for engineering teams.

## Public surface

### .NET

| Type | Role |
|---|---|
| `ISupportTicketService` | Ticket CRUD + status transitions |
| `IIssueTrackerProvider` | External tracker abstraction |
| `MapSupportEndpoints` | `/api/support/*` |
| `services.AddChthonicSupport()` | DI entry point |

### npm

| Export | Role |
|---|---|
| `<SupportTicketsList>` | Customer's own tickets |
| `<ManageSupportTickets>` | Staff queue |
| `<CreateSupportRequest>` | New ticket form |

## Schema

```
support_ticket
  ticket_id         int PK
  system_id         int
  user_id           int FK?
  category          varchar    CTI Category
  type              varchar    CTI Type
  item              varchar    CTI Item
  title             varchar
  body              text
  status            enum 'Open', 'In Progress', 'Resolved', 'Closed'
  resolver_group    varchar?   matched via CTI table
  external_issue_id varchar?   GitHub issue URL (if synced)
  created_at        datetime
  resolved_at       datetime?

cti_routing
  cti_id            int PK
  category          varchar
  type              varchar
  item              varchar
  resolver_group    varchar
  external_provider varchar?   'github', 'linear', 'jira'
  external_repo     varchar?   for github sync
```

## Dependencies

| Dep | Purpose |
|---|---|
| `@chthonic/tenant` | system_id |
| `@chthonic/identity` | User context |
| `@chthonic/feedback` | (optional) link tickets to negative reviews |

## Extension points

| Hook | Use |
|---|---|
| `IIssueTrackerProvider` | Add Linear / Jira / Zendesk sync |
| `cti_routing` table | Tenants/sysadmins configure routing |
| Phase-2 sister packages | `Chthonic.Support.Linear`, etc. |

## Consuming this library

```csharp
builder.Services.AddChthonicSupport();
builder.Services.AddGitHubIssueTracker(builder.Configuration);   // optional
app.MapSupportEndpoints();
```

## Related

- [`architecture.md`](architecture.md), [`consumption.md`](consumption.md), [`extension-points.md`](extension-points.md).
- [`ticketing.md`](ticketing.md), [`cti-routing.md`](cti-routing.md), [`issue-tracker-abstraction.md`](issue-tracker-abstraction.md), [`github-sync.md`](github-sync.md).
- Library repos: [chthonicsystems/support](https://github.com/chthonicsystems/support).
- [RFC 0016](https://github.com/chthonicsystems/architecture/blob/main/rfcs/0016-support-and-helpdesk.md).
