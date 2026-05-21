---
library: feedback
version: 0.1.0
related-rfcs: [0015]
last-verified: 2026-05-22
tags: [feedback, internal-reviews]
summary: Internal review CRUD — write, moderate, list.
---

# Internal reviews

Reviews collected by the platform itself. Customers write reviews from the customer portal; admins moderate.

## Endpoints

```
POST   /api/reviews                                # customer writes
GET    /api/reviews?systemId=&visible=true         # public list
PUT    /api/reviews/{id}/moderate                  # admin sets is_visible
DELETE /api/reviews/{id}                           # admin (rare)
```

## Schema

```
review (review_id, system_id, user_id, rating, body, created_at, is_visible)
```

`is_visible = true` by default; admin can hide spam / abuse.

## Auth

`POST` requires `IReviewAccessProvider.CanWriteAsync(userId, systemId)` to return true. Default impl checks customer has a Completed Job — overrides per consumer.

## Related

- [`google-reviews.md`](google-reviews.md), [`weighted-aggregate.md`](weighted-aggregate.md).
