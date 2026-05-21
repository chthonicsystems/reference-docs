---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, ticketing]
summary: Support ticket lifecycle + endpoints + status transitions.
---

# Ticketing

```
support_ticket
  ticket_id    int PK
  system_id    int
  user_id      int FK?
  category     varchar
  type         varchar
  item         varchar
  title        varchar
  body         text
  status       enum 'Open', 'In Progress', 'Resolved', 'Closed'
  resolver_group varchar?
  external_issue_id varchar?
  created_at   datetime
  resolved_at  datetime?
```

## Endpoints

```
POST   /api/support                    # customer creates
GET    /api/support?userId=...         # customer's own
GET    /api/support/manage             # staff queue (paginated)
GET    /api/support/{id}
PUT    /api/support/{id}/status        # status transitions
POST   /api/support/{id}/comment       # add comment (uses @chthonic/notes)
```

## State transitions

```
Open → In Progress (by staff)
In Progress → Resolved (by staff)
Resolved → Closed (auto after N days, or by customer)
Resolved → Open (reopen by customer)
```

## Related

- [`cti-routing.md`](cti-routing.md), [`github-sync.md`](github-sync.md).
