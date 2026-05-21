---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, cti-routing]
summary: Category/Type/Item routing — match incoming tickets to resolver groups + external issue trackers.
---

# CTI routing

When a ticket is created, `CtiRoutingService.MatchAsync(category, type, item)` returns:

- `resolver_group` — internal team to assign.
- `external_provider` + `external_repo` — optional external sync target.

## Schema

```sql
CREATE TABLE cti_routing (
    cti_id INT PRIMARY KEY AUTO_INCREMENT,
    category VARCHAR(100) NOT NULL,
    type VARCHAR(100) NOT NULL,
    item VARCHAR(200) NOT NULL,
    resolver_group VARCHAR(100) NOT NULL,
    external_provider VARCHAR(50) NULL,    -- 'github', 'linear', 'jira', null
    external_repo VARCHAR(200) NULL,       -- repo / project key
    UNIQUE KEY (category, type, item)
);
```

## Matching rules

Exact match required on all three fields. Wildcard rows (`type='*'`) are not supported at v0.1.0; future enhancement.

If no match found → ticket created without `resolver_group`; admin manually triages.

## Seeding

Sysadmins populate via SQL or a future `/api/cti-routing` admin endpoint.

## Related

- [`ticketing.md`](ticketing.md), [`issue-tracker-abstraction.md`](issue-tracker-abstraction.md).
